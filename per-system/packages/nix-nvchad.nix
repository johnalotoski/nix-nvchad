{
  inputs,
  lib,
  pkgs,
  system,
  cfg,
}: let
  inherit (builtins) elem;
  inherit (lib) concatMapStringsSep;

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
  autoCmds = builtins.toFile "autocmds.lua" ''
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
  chadRc = builtins.toFile "chadrc.lua" ''
    -- This file needs to have same structure as nvconfig.lua
    -- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
    -- Please read that file to know all available options :(

    ---@type ChadrcConfig
    local M = {}

    M.base46 = {
      theme = "midnight_breeze",
      theme_toggle = { "midnight_breeze", "sunrise_breeze" }
      -- hl_override = {
      --  Comment = { italic = true },
      --  ["@comment"] = { italic = true },
      -- },
    }

    M.nvdash = { load_on_startup = true }

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
    treesitterInstall =
      if elem "all" cfg.grammars
      then ''vim.cmd("TSInstall all")''
      else ''require("nvim-treesitter").install({${concatMapStringsSep ", " (g: ''"${g}"'') cfg.grammars}})'';
  in builtins.toFile "init.lua" ''
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

    -- MOD: Any other custom initialization
    require "custom.init"
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/plugins/init.lua
  #
  # See treesitter supported languages at:
  # https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md
  initPlugins = builtins.toFile "init-plugins.lua" ''
    return {
      {
        "stevearc/conform.nvim",
        -- event = 'BufWritePre', -- uncomment for format on save
        opts = require "configs.conform",
      },

      -- These are some examples, uncomment them if you want to see them work!
      {
        "neovim/nvim-lspconfig",
        config = function()
          require "configs.lspconfig"
        end,
      },

      -- MOD: test new blink, enabled
      { import = "nvchad.blink.lazyspec" },

      -- COMMENT: This doesn't work with the new nvim-treesitter API on main
      -- See the alternate treesitter setup in init.lua and lua/custom/init.lua
      -- {
      --  "nvim-treesitter/nvim-treesitter",
      --  opts = {
      --    ensure_installed = {
      --      "vim", "lua", "vimdoc",
      --      "html", "css"
      --    },
      --  },
      -- },
    }
  '';

  # For custom initialization
  initCustom = pkgs.writeText "init-custom.lua" ''
  '';

  # Lazy can't lock itself with its own lock file
  lazyLock = builtins.toFile "lazy-lock.json" ''
    {
      "LuaSnip": { "branch": "master", "commit": "dae4f5aaa3574bd0c2b9dd20fb9542a02c10471c" },
      "NvChad": { "branch": "v2.5", "commit": "c57b82473b821274f6017eb03582ba1d13be9d8c" },
      "base46": { "branch": "v3.0", "commit": "884b990dcdbe07520a0892da6ba3e8d202b46337" },
      "blink.cmp": { "branch": "main", "commit": "b19413d214068f316c78978b08264ed1c41830ec" },
      "conform.nvim": { "branch": "master", "commit": "c2526f1cde528a66e086ab1668e996d162c75f4f" },
      "friendly-snippets": { "branch": "main", "commit": "6cd7280adead7f586db6fccbd15d2cac7e2188b9" },
      "gitsigns.nvim": { "branch": "main", "commit": "abf82a65f185bd54adc0679f74b7d6e1ada690c9" },
      "indent-blankline.nvim": { "branch": "master", "commit": "005b56001b2cb30bfa61b7986bc50657816ba4ba" },
      "mason.nvim": { "branch": "main", "commit": "44d1e90e1f66e077268191e3ee9d2ac97cc18e65" },
      "menu": { "branch": "main", "commit": "7a0a4a2896b715c066cfbe320bdc048091874cc6" },
      "minty": { "branch": "main", "commit": "aafc9e8e0afe6bf57580858a2849578d8d8db9e0" },
      "nvim-autopairs": { "branch": "master", "commit": "007047febaa3681a8d2f3dd5126fdb9c6e81f393" },
      "nvim-lspconfig": { "branch": "master", "commit": "79c9a15be5731bc8694840a8fb0c9141c20a80c0" },
      "nvim-tree.lua": { "branch": "master", "commit": "c07ce43527e5f0242121f4eb1feb7ac0ecea8275" },
      "nvim-treesitter": { "branch": "main", "commit": "19c729dae6e0eeb79423df0cf37780aa9a7cc3b7" },
      "nvim-web-devicons": { "branch": "master", "commit": "803353450c374192393f5387b6a0176d0972b848" },
      "plenary.nvim": { "branch": "master", "commit": "b9fd5226c2f76c951fc8ed5923d85e4de065e509" },
      "telescope.nvim": { "branch": "master", "commit": "ad7d9580338354ccc136e5b8f0aa4f880434dcdc" },
      "ui": { "branch": "v3.0", "commit": "cb75908a86720172594b30de147272c1b3a7f452" },
      "volt": { "branch": "main", "commit": "620de1321f275ec9d80028c68d1b88b409c0c8b1" },
      "which-key.nvim": { "branch": "main", "commit": "3aab2147e74890957785941f0c1ad87d0a44c15a" }
    }
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/configs/lspconfig.lua
  #
  # For available LSPs, view:
  # https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
  lspConfig = builtins.toFile "lspconfig.lua" ''
    require("nvchad.configs.lspconfig").defaults()

    -- LSP servers from either the nix-nvchad package or the environment
    -- When LSP servers are either very large or not used frequently,
    -- they will be expected from the project's env so as not to bloat
    -- the base nix-nvchad package.  If an LSP is defined here, but
    -- noted to be expected from the environment and is not provided,
    -- expect LSP missing binary errors when opening a file of this type.
    local servers = {
      "bashls",         -- Bash
      "clangd",         -- C/C++
      "crystalline",    -- Crystal Lang
      "cssls",          -- CSS
      "eslint",         -- ESLint
      "gh_actions_ls",  -- GHA, from env only
      "gopls",          -- Go
      "hls",            -- Haskell, from env only
      "html",           -- HTML
      "jsonls",         -- JSON
      "lua_ls",         -- Lua
      "marksman",       -- Markdown
      "nixd",           -- Nix
      "nushell",        -- Nushell, from env only
      "pyright",        -- Python
      "rust_analyzer",  -- Rust
      "system_lsp",     -- Systemd
      "taplo",          -- TOML
      "ts_ls",          -- TypeScript/JavaScript
      "yamlls",         -- YAML
    }
    vim.lsp.enable(servers)
    -- read :h vim.lsp.config for changing options of lsp servers
  '';

  # Upstream ref: https://github.com/NvChad/starter/blob/main/lua/options.lua
  options = builtins.toFile "options.lua" ''
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
      fd
      gcc
      git
      gnumake
      gnutar
      gzip
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
        cp ${initCustom} "$CONFIG_DIR"/lua/custom/init.lua
        cp ${initPlugins} "$CONFIG_DIR"/lua/plugins/init.lua
        cp ${lazyLock} "$CONFIG_DIR"/lazy-lock.json
        cp ${lspConfig} "$CONFIG_DIR"/lua/configs/lspconfig.lua
        cp ${options} "$CONFIG_DIR"/lua/options.lua

        # And again, ensure config is writable
        chmod -R u+w "$CONFIG_DIR"
      fi

      exec nvim "''${ARGS[@]}"
    '';
  }
