{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      nixosConfigurations = {
        "workstation" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self; };
          modules = [
            ./host/workstation/configuration.nix
            home-manager.nixosModules.home-manager
          ];
        };
        "scg-client" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self; };
          modules = [
            ./host/scg-client/configuration.nix
            home-manager.nixosModules.home-manager
          ];
        };
        "scg-server" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self; };
          modules = [
            ./host/scg-server/configuration.nix
            home-manager.nixosModules.home-manager
          ];
        };
        "laptop" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self; };
          modules = [
            ./host/laptop/configuration.nix
            home-manager.nixosModules.home-manager
          ];
        };
      };
    };
}
