# Build a customized nix-nvchad package using module options
#
# Usage:
#
#   {
#     inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
#     inputs.nix-nvchad.url = "github:johnalotoski/nix-nvchad";
#
#     outputs = { nixpkgs, nix-nvchad, ... }:
#     let
#       system = "x86_64-linux";
#       pkgs = import nixpkgs { inherit system; };
#     in {
#       packages.${system}.default = nix-nvchad.lib.mkNixNvchad {
#         inherit pkgs;
#         modules = [
#           {
#             fallbackInputs = with pkgs; [ gopls rust-analyzer nixd ];
#           }
#         ];
#       };
#     };
#   }
#
{
  inputs,
  lib,
  system,
}:
{
  pkgs,
  modules ? [],
}:
let
  # Evaluate the module system with user-provided modules
  evaluated = lib.evalModules {
    modules =
      [
        ./options.nix
        {
          # Make pkgs available to the options module
          _module.args = {inherit pkgs;};
        }
      ]
      ++ modules;
  };

  # Extract the evaluated config
  cfg = evaluated.config;
in
  import ../per-system/packages/nix-nvchad.nix {
    inherit inputs lib pkgs system;
    inherit (cfg) fallbackInputs;
  }
