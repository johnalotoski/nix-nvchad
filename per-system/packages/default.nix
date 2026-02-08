{
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  # Use the module system to get default config
  mkNixNvchad = import ../../lib/mkNixNvchad.nix {inherit inputs lib system;};

  nix-nvchad = mkNixNvchad {inherit pkgs;};
in {
  default = nix-nvchad;
  inherit nix-nvchad;
  neovim = pkgs.neovim;
}
