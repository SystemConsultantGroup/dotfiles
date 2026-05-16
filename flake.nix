{
  description = "Donghyun Shin's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kime.url = "github:apersomany/kime";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      username = "aperso";
      userFullName = "Donghyun Shin";
      gitUserName = "apersomany";
      gitUserEmail = "aperso@aperso.dev";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit self inputs username userFullName gitUserName gitUserEmail; };
          modules = [ (./. + "/hosts/${name}/configuration.nix") ];
        };
    in
    {
      inherit (inputs.self) description;

      nixosConfigurations = {
        workstation = mkHost "workstation";
        laptop = mkHost "laptop";
      };

      nixosModules = {
        base = ./modules/base;
        client = ./modules/client;
        server = ./modules/server;
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt-rfc-style
          nil
          nixd
          statix
          deadnix
          direnv
        ];
      };
    };
}
