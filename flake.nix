{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kime = {
      url = "github:Riey/kime/develop";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      kime,
      ...
    }:
    {
      nixosConfigurations = {
        "workstation" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self kime; };
          modules = [
            ./host/workstation/configuration.nix
            home-manager.nixosModules.home-manager
          ];
        };
        "laptop" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self kime; };
          modules = [
            ./host/laptop/configuration.nix
            home-manager.nixosModules.home-manager
          ];
        };
      };
    };
}
