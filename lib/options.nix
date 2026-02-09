# Module options for nix-nvchad configuration
#
# To view some of the evaluated option descriptions, use:
#   nix repl
#   :lf .
#   :p lib.options.${system}.$OPTION.description
{
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) sort;
  inherit (lib) concatStringsSep mkAfter mkOption types unique;
  inherit (types) listOf package str;

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
    black                                    # Python
    nixfmt-rfc-style                         # Nix
    nodePackages.prettier                    # JS/TS/HTML/CSS/JSON/MD
    shfmt                                    # Shell
    stylua                                   # Lua

    # Linters
    shellcheck                               # Shell
    statix                                   # Nix
  ];
in {
  options = {
    appName = mkOption {
      type = str;
      default = "nix-nvchad";
      description = ''
        Application name used for the binary name, NVIM_APPNAME, and XDG directory paths.
        This allows creating multiple distinct nix-nvchad configurations with different names.
      '';
    };

    fallbackInputs = mkOption {
      type = listOf package;
      default = [];
      apply = unique;
      description = ''
        List of packages to include as fallback tools (LSP servers, formatters, linters).
        These are added to PATH after the project environment, so project-specific
        tools take precedence.

        A relatively lightweight default set is included, consisting of:

        ```
        ${concatStringsSep "\n" (sort (a: b: a < b) (map (p: p.name) fallbackInputs))}
        ```

        To add to the default list of packages, simply declare more and they
        will be merged with the default list at higher path priority.

        To override the default list of packages, use `mkForce` in the declaration.
      '';
    };

    neovim = mkOption {
      type = package;
      default = pkgs.neovim-unwrapped;
      description = ''
        Base neovim package to use. This can be `pkgs.neovim-unwrapped` from nixpkgs
        or an alternative like `neovim-nightly-overlay`'s unwrapped package.

        The provided package will have treesitter parsers stripped from
        `lib/nvim/parser` to avoid conflicts with lazy-managed parsers.
      '';
    };
  };

  config = {
    fallbackInputs = mkAfter fallbackInputs;
  };
}
