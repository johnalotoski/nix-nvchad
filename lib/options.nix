# Module options for nix-nvchad configuration
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (types) listOf package;

  defaultFallbackInputs = with pkgs; [
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
  options = {
    fallbackInputs = mkOption {
      type = listOf package;
      default = defaultFallbackInputs;
      description = ''
        List of packages to include as fallback tools (LSP servers, formatters, linters).
        These are added to PATH after the project environment, so project-specific
        tools take precedence.
      '';
    };
  };
}
