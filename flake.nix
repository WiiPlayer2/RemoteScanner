{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?rev=a30e284fcd69aadaec15c563b1649667fc77cd4d";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { ... } @ inputs:
    let
      system = "x86_64-linux";
      args = {
        inherit system inputs;
      };
    in {
      devShells.${system}.default = import ./nix/shell.nix args;
    };
}
