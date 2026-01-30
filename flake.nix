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

    tree-sitter.url = "github:tree-sitter/tree-sitter/v0.26.3";
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

      print("DEBUG: end")
    '';

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
        "lazy.nvim": { "branch": "main", "commit": "306a05526ada86a7b30af95c5cc81ffba93fef97" },
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

          # Enable compiling additional language grammars on demand from source file.
          # The tree-sitter version will need to be compatible with the lazy-lock.json pin.
          self.inputs.tree-sitter.packages.${system}.cli
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

            # Copy Lazy plugin lock file
            cp ${lazyLock} "$CONFIG_DIR"/lazy-lock.json

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
