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

  outputs = inputs: let
    inherit (inputs.nixpkgs) lib;
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      inherit systems;

      flake = {
        # Export lib.mkNixNvchad for downstream customization
        lib = {
          mkNixNvchad = {
            pkgs,
            system ? pkgs.stdenv.hostPlatform.system,
            modules ? [],
          }:
            import ./lib/mkNixNvchad.nix {inherit inputs lib system;} {
              inherit pkgs modules;
            };

          # Per-system options accessor, for inspection @ options.${system}...
          options = lib.genAttrs systems (system:
            let
              pkgs = import inputs.nixpkgs { inherit system; };
              evaluated = lib.evalModules {
                modules = [
                  ./lib/options.nix
                  { _module.args = { inherit pkgs; }; }
                ];
              };
            in evaluated.options
          );
        };
      };

      perSystem = {
        lib,
        pkgs,
        self',
        system,
        ...
      }: let
        evaluated = lib.evalModules {
          modules = [
            ./lib/options.nix
            {_module.args = {inherit pkgs;};}
          ];
        };

        optionsDoc = pkgs.nixosOptionsDoc {
          options = evaluated.options;
          transformOptions = opt: opt // {
            declarations = [];
          };
        };

        packages =
          import ./per-system/packages {
            inherit inputs lib pkgs system;
          }
          // {
            docs-md = optionsDoc.optionsCommonMark;
            docs-json = optionsDoc.optionsJSON;
          };
      in {
        inherit packages;

        devShells.default = pkgs.mkShell {
          packages = [self'.packages.default];
        };
      };
    };
}
