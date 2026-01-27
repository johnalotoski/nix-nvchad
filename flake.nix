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
  in {
    packages.${system} = rec {
      default = nix-nvchad;

      nix-nvchad = let
        appName = "nix-nvchad";
      in pkgs.writeShellApplication {
        name = appName;
        runtimeInputs = with pkgs; [neovim];
        text = ''
          CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/${appName}"
          if [ ! -e "$CONFIG_DIR/init.lua" ]; then
            mkdir -p "$CONFIG_DIR"
            cp -r ${self.inputs.nvchad-starter}/* "$CONFIG_DIR/"
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
