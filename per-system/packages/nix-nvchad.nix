{
  inputs,
  lib,
  pkgs,
  system,
  cfg,
}: let
  inherit (builtins) elem toFile toJSON;
  inherit (lib) boolToString concatMapStringsSep getExe;
  inherit (pkgs) jq runCommandLocal;

  # Sanitize neovim by stripping treesitter parsers to avoid conflicts with lazy-managed parsers
  neovim-sanitized = cfg.neovim.overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        echo "Removing lib/nvim/parser from neovim output to avoid treesitter conflicts..."
        rm -rf $out/lib/nvim/parser || true
      '';
  });

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/autocmds.lua
  autoCmds = toFile "autocmds.lua" ''
    require "nvchad.autocmds"

    local autocmd = vim.api.nvim_create_autocmd

    -- Show trailing whitespace
    vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "LightCoral" })
    autocmd("ColorScheme", {
      pattern = "*",
      callback = function()
        vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "LightCoral" })
      end,
    })
    autocmd("BufEnter", {
      pattern = "*",
      command = [[match ExtraWhitespace /\s\+$/]],
    })
    autocmd("InsertEnter", {
      pattern = "*",
      command = [[match ExtraWhitespace /\s\+\%#\@<!$/]],
    })
    autocmd("InsertLeave", {
      pattern = "*",
      command = [[match ExtraWhitespace /\s\+$/]],
    })

    -- Show tabs
    vim.api.nvim_set_hl(0, "Tabs", { bg = "SteelBlue" })
    autocmd("ColorScheme", {
      pattern = "*",
      callback = function()
        vim.api.nvim_set_hl(0, "Tabs", { bg = "SteelBlue" })
      end,
    })
    autocmd({ "BufEnter", "InsertEnter", "InsertLeave" }, {
      pattern = "*",
      command = [[2match Tabs /\t\+/]],
    })

    -- Trim trailing whitespace on save
    autocmd("BufWritePre", {
      pattern = "*",
      command = [[%s/\s\+$//e]],
    })

    -- Retab on save
    autocmd("BufWritePre", {
      pattern = "*",
      command = "retab",
    })
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/chadrc.lua
  chadRc = toFile "chadrc.lua" ''
    -- This file needs to have same structure as nvconfig.lua
    -- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
    -- Please read that file to know all available options :(

    ---@type ChadrcConfig
    local M = {}

    M.base46 = {
      theme = "${cfg.theme}",
      theme_toggle = { "${cfg.themeToggleLeft}", "${cfg.themeToggleRight}" }
      -- hl_override = {
      --  Comment = { italic = true },
      --  ["@comment"] = { italic = true },
      -- },
    }

    M.nvdash = { load_on_startup = ${boolToString cfg.enableSplash} }

    -- M.ui = {
    --       tabufline = {
    --          lazyload = false
    --      }
    -- }

    return M
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/init.lua
  init = let
    # Grammar install command for config function (runs on each startup)
    #
    # See treesitter supported languages at:
    # https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md
    treesitterInstall =
      if elem "all" cfg.grammars
      then ''vim.cmd("TSInstall all")''
      else ''require("nvim-treesitter").install({${concatMapStringsSep ", " (g: ''"${g}"'') cfg.grammars}})'';
  in toFile "init.lua" ''
    vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
    vim.g.mapleader = " "

    -- bootstrap lazy and all plugins
    local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

    if not vim.uv.fs_stat(lazypath) then
      local repo = "https://github.com/folke/lazy.nvim.git"
      vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
    end

    vim.opt.rtp:prepend(lazypath)

    local lazy_config = require "configs.lazy"

    -- load plugins
    require("lazy").setup({
      {
        "NvChad/NvChad",
        lazy = false,
        branch = "v2.5",
        import = "nvchad.plugins",
      },

      -- MOD: To enforce treesitter grammar install on startup
      {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        config = function()
          require("nvim-treesitter").setup({
            highlight = { enable = true },
            auto_install = true,
            install_dir = vim.fn.stdpath("data") .. "/site",
          })
          -- Ensure configured grammars are installed on each startup
          ${treesitterInstall}
        end
      },

      -- MOD: To avoid having to double-press the leader key on first invocation when lazy loaded
      {
        "folke/which-key.nvim",
        lazy = false,
      },

      -- Load other plugins
      { import = "plugins" },
    }, lazy_config)

    -- load theme
    dofile(vim.g.base46_cache .. "defaults")
    dofile(vim.g.base46_cache .. "statusline")

    require "options"
    require "autocmds"

    vim.schedule(function()
      require "mappings"
    end)
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/plugins/init.lua
  initPlugins = toFile "init-plugins.lua" ''
    return {
      {
        "stevearc/conform.nvim",
        -- event = 'BufWritePre', -- uncomment for format on save
        opts = require "configs.conform",
      },

      {
        "neovim/nvim-lspconfig",
        config = function()
          require "configs.lspconfig"
        end,
      },

      { import = "nvchad.blink.lazyspec" },
    }
  '';

  lazyLock = let
    lazyLockCompact = toFile "lazy-lock-compact.json" (toJSON cfg.lazyLock);
  in runCommandLocal "lazy-lock.json" {} ''
    ${getExe jq} --sort-keys . < ${lazyLockCompact} > $out
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/configs/lspconfig.lua
  #
  # For available LSPs, view:
  # https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
  lspConfig = let
    servers = concatMapStringsSep ", " (s: ''"${s}"'') cfg.lspServers;
  in toFile "lspconfig.lua" ''
    require("nvchad.configs.lspconfig").defaults()

    -- LSP servers from either the nix-nvchad packages fallbackInputs or the environment.
    --
    -- When LSP servers are either very large or not used frequently,
    -- they will be expected from the project's env so as not to bloat
    -- the base nix-nvchad package.  If an LSP is defined here, but
    -- not provided by package or environment, expect LSP missing binary
    -- errors when opening a file of this type.
    local servers = {${servers}}
    vim.lsp.enable(servers)
    -- read :h vim.lsp.config for changing options of lsp servers
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/options.lua
  options = toFile "options.lua" ''
    require "nvchad.options"

    local opt = vim.opt
    opt.autoindent = true
    opt.cursorcolumn = true
    opt.cursorlineopt = "both"
    opt.cursorline = true
    opt.expandtab = true

    -- Defaults via `:set formatoptions?` are `tcqj`
    opt.formatoptions:append "r" -- Continue comments on Enter
    opt.formatoptions:append "o" -- Continue comments on 'o'

    opt.shiftwidth = 2
    opt.tabstop = 2
  '';
in
  pkgs.writeShellApplication {
    name = cfg.appName;

    # Pass the parent environment path to neovim
    inheritPath = true;

    runtimeInputs = with pkgs; [
      neovim-sanitized

      # Core tools for neovim plugins (telescope, treesitter, etc.)
      coreutils
      curl
      difftastic
      fd
      gcc
      git
      gnumake
      gnutar
      gzip
      jq
      nodejs
      ripgrep

      # Enable compiling additional language grammars on demand from source file.
      # The tree-sitter version will need to be compatible with the lazy-lock.json pin.
      # Current main requires >= v0.26.1 tree-sitter cli.
      inputs.tree-sitter.packages.${system}.cli
    ];

    text = ''
      [ -n "''${DEBUG:-}" ] && set -x

      # Runtime inputs paths and parent shell paths if inheritPath is true
      REQUIRED_PATHS="$PATH"

      # Fallback paths
      FALLBACK_PATHS="${lib.makeBinPath cfg.fallbackInputs}"

      # Per projects envs can override the fallback bins
      export PATH="$REQUIRED_PATHS:$FALLBACK_PATHS"

      # Export the nvim namespacing
      export NVIM_APPNAME=${cfg.appName}

      CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/${cfg.appName}"
      DATA_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/${cfg.appName}"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/${cfg.appName}"

      # Check for custom flags
      REINSTALL=false
      REINSTALL_CONFIG=false
      REINSTALL_DATA=false
      ARGS=()
      for ARG in "$@"; do
        case "$ARG" in
          --reinstall)
            REINSTALL=true
            ;;
          --reinstall-config)
            REINSTALL_CONFIG=true
            ;;
          --reinstall-data)
            REINSTALL_DATA=true
            ;;
          *)
            ARGS+=("$ARG")
            ;;
        esac
      done

      # Handle reinstall: purge all config/data/state and bootstrap fresh
      if [ "$REINSTALL" = true ]; then
        echo "Reinstalling ${cfg.appName} in 4 seconds..."
        echo "Press CTRL-C to cancel..."
        sleep 4
        echo "Removing config: $CONFIG_DIR"
        rm -rf "$CONFIG_DIR"
        echo "Removing data: $DATA_DIR"
        rm -rf "$DATA_DIR"
        echo "Removing state: $STATE_DIR"
        rm -rf "$STATE_DIR"
      else
        # Handle reinstall-config: purge only config and bootstrap fresh
        if [ "$REINSTALL_CONFIG" = true ]; then
          echo "Reinstalling config for ${cfg.appName} in 4 seconds..."
          echo "Press CTRL-C to cancel..."
          sleep 4
          echo "Removing config: $CONFIG_DIR"
          rm -rf "$CONFIG_DIR"
          echo
        fi

        # Handle reinstall-data: purge only data (plugins, parsers)
        if [ "$REINSTALL_DATA" = true ]; then
          echo "Reinstalling data for ${cfg.appName} in 4 seconds..."
          echo "Press CTRL-C to cancel..."
          sleep 4
          echo "Removing data: $DATA_DIR"
          rm -rf "$DATA_DIR"
        fi
      fi

      # Bootstrap config if not present
      if ! [ -e "$CONFIG_DIR/init.lua" ]; then
        mkdir -p "$CONFIG_DIR/lua/custom"

        # Copy upstream nvchad config
        cp -r ${inputs.nvchad-starter}/* "$CONFIG_DIR/"

        # Explicitly overwrite upstream config with our custom files
        chmod -R u+w "$CONFIG_DIR"
        cp ${autoCmds} "$CONFIG_DIR"/lua/autocmds.lua
        cp ${chadRc} "$CONFIG_DIR"/lua/chadrc.lua
        cp ${init} "$CONFIG_DIR"/init.lua
        cp ${initPlugins} "$CONFIG_DIR"/lua/plugins/init.lua
        cp ${lazyLock} "$CONFIG_DIR"/lazy-lock.json
        cp ${lspConfig} "$CONFIG_DIR"/lua/configs/lspconfig.lua
        cp ${options} "$CONFIG_DIR"/lua/options.lua

        # And again, ensure config is writable
        chmod -R u+w "$CONFIG_DIR"
      fi

      # Obtain a canonical form of the lazy-lock.json data.
      # Exclude any "lazy.nvim" json key value pair as lazy cannot lock itself via its own lock file.
      LAZY_LOCK=$(jq --sort-keys 'del(."lazy.nvim")' < "$CONFIG_DIR"/lazy-lock.json)

      # Lazy serializes the lazy-lock.json file to its own format regularly.
      # Compare the declared values to the actual contents, both in canonical form, to ensure they remain the same.
      if ! difft --check-only --exit-code ${lazyLock} <(echo "$LAZY_LOCK") &> /dev/null; then
        echo "Lazy lock contents appear to have changed:"
        echo
        echo "Left column is the declared content, right column is the current lazy-lock.json content"
        difft ${lazyLock} <(echo "$LAZY_LOCK")
        echo
        read -r -p "Restore declared lock? [y/N] " RESPONSE
        if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
          cp ${lazyLock} "$CONFIG_DIR"/lazy-lock.json
          echo "Lock file restored."
          read -r -p "Run Lazy restore now (headless)? [y/N] " RESPONSE
          if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
            nvim --headless "+Lazy! restore" +qa
          else
            echo "Run ':Lazy restore' in neovim to sync plugins."
          fi
        fi
        read -s -r -n 1 -p "Press a key to continue..."
      fi

      exec nvim "''${ARGS[@]}"
    '';
  }
