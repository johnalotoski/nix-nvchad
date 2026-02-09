# Build a customized nix-nvchad package using module options.
# This example includes neovim-nightly usage with fallbackInputs mods.
#
# Usage:
#
#   {
#     inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
#     inputs.nix-nvchad.url = "github:johnalotoski/nix-nvchad";
#     inputs.neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
#
#     outputs = { nixpkgs, nix-nvchad, neovim-nightly, ... }:
#     let
#       system = "x86_64-linux";
#       pkgs = import nixpkgs { inherit system; };
#     in {
#       packages.${system}.default = nix-nvchad.lib.mkNixNvchad {
#         inherit pkgs;
#         modules = [
#           {
#             # Use the nix-community neovim-nightly package instead of the
#             # default nixpkgs neovim-unwrapped.
#             neovim = neovim-nightly.packages.${system}.neovim;
#
#             # This will merge hls into the default fallbackInputs.
#             # Add a `mkForce` to override the list to exclusively hls.
#             fallbackInputs = with pkgs; [ haskell-language-server ];
#           }
#         ];
#       };
#     };
#   }
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
    inherit (cfg) fallbackInputs neovim;
  }
