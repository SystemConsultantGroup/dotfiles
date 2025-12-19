{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    {
      nixosConfigurations = {
        "workstation" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./host/workstation/configuration.nix
            home-manager.nixosModules.home-manager
          ];
          specialArgs = { inherit home-manager; };
        };
      };
    };
}
