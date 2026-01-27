{
  description = "A flake providing mutable and immutable nvChad nix packages";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    nvchad-starter = {
      url = "github:NvChad/starter";
      flake = false;
    };
  };

  outputs = {self, ...}:
  let
    system = "x86_64-linux";

    mkPkgs = input:
      import self.inputs.${input} {inherit system;};

    pkgs = mkPkgs "nixpkgs";

    autoCmds = builtins.toFile "autocmds.lua" ''
      require "nvchad.autocmds"

      local autocmd = vim.api.nvim_create_autocmd

      -- Show trailing whitespace
      vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red" })
      autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "ExtraWhitespace", { bg = "red" })
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
      vim.api.nvim_set_hl(0, "Tabs", { bg = "blue" })
      autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "Tabs", { bg = "blue" })
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

    lspConfig = builtins.toFile "lspconfig.lua" ''
      require("nvchad.configs.lspconfig").defaults()

      -- LSP servers available via Nix (no Mason needed)
      local servers = {
        "nixd",           -- Nix
        "rust_analyzer",  -- Rust
        "pyright",        -- Python
        "lua_ls",         -- Lua
        "gopls",          -- Go
        "clangd",         -- C/C++
        "marksman",       -- Markdown
        "taplo",          -- TOML
        "yamlls",         -- YAML
        "ts_ls",          -- TypeScript/JavaScript
        "bashls",         -- Bash
        "html",           -- HTML
        "cssls",          -- CSS
        "jsonls",         -- JSON
        "eslint",         -- ESLint
      }
      vim.lsp.enable(servers)
      -- read :h vim.lsp.config for changing options of lsp servers
    '';
  in {
    packages.${system} = rec {
      default = nix-nvchad;

      nix-nvchad = let
        appName = "nix-nvchad";
      in pkgs.writeShellApplication {
        name = appName;
        runtimeInputs = with pkgs; [
          neovim

          # Core tools for neovim plugins (telescope, treesitter, etc.)
          gcc
          git
          gnumake
          nodejs
          ripgrep
          fd

          # LSP servers
          nixd                                     # Nix
          rust-analyzer                            # Rust
          pyright                                  # Python
          lua-language-server                      # Lua
          gopls                                    # Go
          clang-tools                              # C/C++ (clangd)
          marksman                                 # Markdown
          taplo                                    # TOML
          yaml-language-server                     # YAML
          nodePackages.typescript-language-server  # TypeScript/JavaScript
          nodePackages.bash-language-server        # Bash
          vscode-langservers-extracted             # HTML, CSS, JSON, ESLint

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
        text = ''
          CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/${appName}"
          if [ ! -e "$CONFIG_DIR/init.lua" ]; then
            mkdir -p "$CONFIG_DIR"

            # Copy base nvchad config
            cp -r ${self.inputs.nvchad-starter}/* "$CONFIG_DIR/"

            # Some features such as theme toggling require writable config
            chmod -R u+w "$CONFIG_DIR"

            # Copy autocmds
            cp ${autoCmds} "$CONFIG_DIR"/lua/autocmds.lua

            # Copy lspConfig
            cp ${lspConfig} "$CONFIG_DIR"/lua/configs/lspconfig.lua

            # And again
            chmod -R u+w "$CONFIG_DIR"
          fi
          export NVIM_APPNAME=${appName}
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
