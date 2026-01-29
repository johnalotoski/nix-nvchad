{
  description = "A flake providing mutable and immutable nvChad nix packages";

  # TODO
  # nerd-font
  # map init to source with append
  # fix up treesitter

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    nvchad-starter = {
      url = "github:NvChad/starter";
      flake = false;
    };
  };

  outputs = {self, ...}:
  let
    inherit (pkgs) lib;

    system = "x86_64-linux";

    mkPkgs = input:
      import self.inputs.${input} {inherit system;};

    pkgs = mkPkgs "nixpkgs";

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

    init = builtins.toFile "init.lua" ''
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

      pcall(require, "custom.init")
    '';

    # See treesitter supported languages at:
    # https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md
    #
    # or `TSInstall <tab>` to see a list
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

        -- test new blink
        { import = "nvchad.blink.lazyspec" },

        -- {
        --  "nvim-treesitter/nvim-treesitter",
        --  opts = {
        --    ensure_installed = {
        --      "css",
        --      "html",
        --      "lua",
        --      "vim",
        --      "vimdoc",
        --     },
        --   },
        -- },
      }
    '';

    # For advanced custom lua config
    initCustom = pkgs.writeText "init-custom.lua" ''
      print("DEBUG: custom/init.lua is loading!")
      local ts_bundle = os.getenv("TS_BUNDLE")

      if ts_bundle and vim.uv.fs_stat(ts_bundle) then
        vim.opt.rtp:prepend(ts_bundle)
      end

      print("DEBUG: end")
    '';

    # For available LSPs, view:
    # https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
    lspConfig = builtins.toFile "lspconfig.lua" ''
      require("nvchad.configs.lspconfig").defaults()

      -- LSP servers available via Nix (no Mason needed)
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

    fallbackInputs = with pkgs; [
      # LSP servers
      clang-tools                              # C/C++ (clangd)
      crystalline                              # Crystal Lang
      gopls                                    # Go
      lua-language-server                      # Lua
      marksman                                 # Markdown
      nixd                                     # Nix
      nodePackages.bash-language-server        # Bash
      nodePackages.typescript-language-server  # TypeScript/JavaScript
      pyright                                  # Python
      rust-analyzer                            # Rust
      systemd-lsp                              # Systemd
      taplo                                    # TOML
      vscode-langservers-extracted             # HTML, CSS, JSON, ESLint
      yaml-language-server                     # YAML

      # Formatters
      stylua                                   # Lua
      black                                    # Python
      nixfmt-rfc-style                         # Nix
      nodePackages.prettier                    # JS/TS/HTML/CSS/JSON/MD
      shfmt                                    # Shell

      # Linters
      shellcheck                               # Shell
      statix                                   # Nix
    ];

    tsBundle = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
      p.nu
      p.haskell
    ]);
  in {
    packages.${system} = rec {
      default = nix-nvchad;

      nix-nvchad = let
        appName = "nix-nvchad";
      in pkgs.writeShellApplication {
        name = appName;

        # Keep the existing
        runtimeInputs = with pkgs; [
          neovim

          # Core tools for neovim plugins (telescope, treesitter, etc.)
          gcc
          git
          gnumake
          nodejs
          ripgrep
          fd

          # Enable compiling additions language grammars on demand from source life
          tree-sitter

        ];
        text = ''
          [ -n "''${DEBUG:-}" ] && set -x

          # Runtime inputs paths and parent shell paths
          REQUIRED_PATHS="$PATH"

          # Fallback paths
          FALLBACK_PATHS="${lib.makeBinPath fallbackInputs}"

          # Per projects envs can override the fallback bins
          export PATH="$REQUIRED_PATHS:$FALLBACK_PATHS"

          # Export the nvim namespacing
          export NVIM_APPNAME=${appName}

          # Export the treesitter grammar tsBundle
          export TS_BUNDLE="${tsBundle}"

          CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/${appName}"
          if [ ! -e "$CONFIG_DIR/init.lua" ]; then
            mkdir -p "$CONFIG_DIR/lua/custom"

            # Copy base nvchad config
            cp -r ${self.inputs.nvchad-starter}/* "$CONFIG_DIR/"

            # Some features such as theme toggling require writable config
            chmod -R u+w "$CONFIG_DIR"

            # Copy autocmds
            cp ${autoCmds} "$CONFIG_DIR"/lua/autocmds.lua

            # Copy chadrc
            cp ${chadRc} "$CONFIG_DIR"/lua/chadrc.lua

            # Copy init
            cp ${init} "$CONFIG_DIR"/init.lua

            # Copy custom init
            cp ${initCustom} "$CONFIG_DIR"/lua/custom/init.lua

            # Copy plugins init
            cp ${initPlugins} "$CONFIG_DIR"/lua/plugins/init.lua

            # Copy lspconfig
            cp ${lspConfig} "$CONFIG_DIR"/lua/configs/lspconfig.lua

            # Copy options
            cp ${options} "$CONFIG_DIR"/lua/options.lua

            # And again
            chmod -R u+w "$CONFIG_DIR"
          fi
          exec ${pkgs.neovim}/bin/nvim "$@"
        '';
      };
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = [self.packages.${system}.default];
      shellHook = ''
      '';
    };
  };
}
