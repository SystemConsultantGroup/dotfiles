{
  description = "Donghyun Shin's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kime.url = "github:apersomany/kime";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHost = name: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit self inputs; };
        modules = [ (./. + "/host/${name}/configuration.nix") ];
      };
    in
    {
      inherit (inputs.self) description;

      nixosConfigurations = {
        workstation = mkHost "workstation";
        laptop = mkHost "laptop";
      };

      nixosModules = {
        base = ./module/base;
        client = ./module/client;
        server = ./module/server;
      };

      formatter.${system} = pkgs.nixfmt-rfc-style;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt-rfc-style
          nil
          nixd
          statix
          deadnix
        ];
      };
    };
}
