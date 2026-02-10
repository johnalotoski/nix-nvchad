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
  inherit (builtins) attrNames elem sort;
  inherit (lib) concatStringsSep generators mkAfter mkOption types unique;
  inherit (types) attrsOf listOf package str;

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

  grammars = [
    "css"
    "html"
    "lua"
    "vim"
    "vimdoc"
    "go"
    "nix"
    "nu"
    "query"
  ];

  # Lazy can't lock itself with its own lock file
  lazyLock = {
    LuaSnip = {
      branch = "master";
      commit = "dae4f5aaa3574bd0c2b9dd20fb9542a02c10471c";
    };

    NvChad = {
      branch = "v2.5";
      commit = "c57b82473b821274f6017eb03582ba1d13be9d8c";
    };

    base46 = {
      branch = "v3.0";
      commit = "884b990dcdbe07520a0892da6ba3e8d202b46337";
    };

    "blink.cmp" = {
      branch = "main";
      commit = "b19413d214068f316c78978b08264ed1c41830ec";
    };

    "conform.nvim" = {
      branch = "master";
      commit = "c2526f1cde528a66e086ab1668e996d162c75f4f";
    };

    friendly-snippets = {
      branch = "main";
      commit = "6cd7280adead7f586db6fccbd15d2cac7e2188b9";
    };

    "gitsigns.nvim" = {
      branch = "main";
      commit = "abf82a65f185bd54adc0679f74b7d6e1ada690c9";
    };

    "indent-blankline.nvim" = {
      branch = "master";
      commit = "005b56001b2cb30bfa61b7986bc50657816ba4ba";
    };

    "mason.nvim" = {
      branch = "main";
      commit = "44d1e90e1f66e077268191e3ee9d2ac97cc18e65";
    };

    menu = {
      branch = "main";
      commit = "7a0a4a2896b715c066cfbe320bdc048091874cc6";
    };

    minty = {
      branch = "main";
      commit = "aafc9e8e0afe6bf57580858a2849578d8d8db9e0";
    };

    nvim-autopairs = {
      branch = "master";
      commit = "007047febaa3681a8d2f3dd5126fdb9c6e81f393";
    };

    nvim-lspconfig = {
      branch = "master";
      commit = "79c9a15be5731bc8694840a8fb0c9141c20a80c0";
    };

    "nvim-tree.lua" = {
      branch = "master";
      commit = "c07ce43527e5f0242121f4eb1feb7ac0ecea8275";
    };

    nvim-treesitter = {
      branch = "main";
      commit = "19c729dae6e0eeb79423df0cf37780aa9a7cc3b7";
    };

    nvim-web-devicons = {
      branch = "master";
      commit = "803353450c374192393f5387b6a0176d0972b848";
    };

    "plenary.nvim" = {
      branch = "master";
      commit = "b9fd5226c2f76c951fc8ed5923d85e4de065e509";
    };

    "telescope.nvim" = {
      branch = "master";
      commit = "ad7d9580338354ccc136e5b8f0aa4f880434dcdc";
    };

    ui = {
      branch = "v3.0";
      commit = "cb75908a86720172594b30de147272c1b3a7f452";
    };

    volt = {
      branch = "main";
      commit = "620de1321f275ec9d80028c68d1b88b409c0c8b1";
    };

    "which-key.nvim" = {
      branch = "main";
      commit = "3aab2147e74890957785941f0c1ad87d0a44c15a";
    };
  };

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

    grammars = mkOption {
      type = listOf str;
      default = [];
      apply = unique;
      description = ''
        List of nvim-treesitter grammars to include.  The list elements must
        consist of supported treesitter grammars.  Such a list can be found at:

        <https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md>

        A small default set is included, consisting of:

        ```
        ${concatStringsSep "\n" (sort (a: b: a < b) grammars)}
        ```

        To add to the default list of grammars, simply declare more and they
        will be merged with the default list.

        To override the default list of grammar, use `mkForce` in the
        declaration.

        If the "all" grammar is found in the list, all available grammars will
        be installed.
      '';
    };

    lazyLock = mkOption {
      type = attrsOf (attrsOf str);
      default = {};
      apply = value:
        if elem "lazy.nvim" (attrNames value)
        then throw "lazyLock must not contain 'lazy.nvim' - Lazy cannot lock itself"
        else value;
      description = ''
        Lazy plugins to use, each with respective locking information required
        by the lazy spec.

        A default set is included, consisting of:

        ```
        ${generators.toPretty {} lazyLock}
        ```

        To add to the default set of plugins, simply declare more and they
        will be shallow merged with the default set.

        To override the default list of plugins, use `mkForce` in the
        declaration.

        Since Lazy plugin cannot lock itself, the addition of `lazy.nvim` is
        not allowed.
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
    inherit lazyLock;

    fallbackInputs = mkAfter fallbackInputs;
    grammars = mkAfter grammars;
  };
}
