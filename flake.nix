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
      username = "aperso";
      userFullName = "Donghyun Shin";
      gitUserName = "apersomany";
      gitUserEmail = "aperso@aperso.dev";
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              self
              inputs
              username
              userFullName
              gitUserName
              gitUserEmail
              ;
          };
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            (./. + "/hosts/${name}/configuration.nix")
          ];
        };
    in
    {
      nixosConfigurations = {
        workstation = mkHost "workstation";
        laptop = mkHost "laptop";
      };

      nixosModules = {
        base = ./modules/base;
        client = ./modules/client;
      };

      formatter.x86_64-linux = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [
          pkgs.treefmt
          pkgs.stylua
          pkgs.nixfmt
        ];
        text = ''
          exec treefmt "$@"
        '';
      };

      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
