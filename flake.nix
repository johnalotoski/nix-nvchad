{
  description = "A flake providing mutable and immutable nvChad nix packages";

  # TODO
  # nerd-font
  # map init to source with append
  # grammar module
  # lua debug module

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";

    nvchad-starter = {
      url = "github:NvChad/starter";
      flake = false;
    };

    tree-sitter.url = "github:tree-sitter/tree-sitter/v0.26.3";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        inputs',
        lib,
        pkgs,
        self',
        system,
        ...
      }: let
        nvim-sanitized = final: prev: {
          neovim-unwrapped = prev.neovim-unwrapped.overrideAttrs (oldAttrs: {
            postInstall =
              (oldAttrs.postInstall or "")
              + ''
                echo "Removing lib/nvim/parser from neovim output to avoid treesitter conflicts..."
                rm -rf $out/lib/nvim/parser || true
              '';
          });
        };

        customPkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [nvim-sanitized];
        };

        packages = import ./per-system/packages {
          inherit inputs lib system;
          pkgs = customPkgs;
        };
      in {
        inherit packages;

        devShells.default = customPkgs.mkShell {
          packages = [self'.packages.default];
        };
      };
    };
}
