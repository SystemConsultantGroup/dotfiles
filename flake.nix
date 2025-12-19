{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };
  outputs =
    { nixpkgs, ... }:
    {
      nixosConfigurations = {
        "workstation" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./host/workstation/configuration.nix
          ];
        };
      };
    };
}
