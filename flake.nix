{
  description = "Donghyun Shin's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kime.url = "github:apersomany/kime";
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
  };

  nixConfig = {
    extra-substituters = [ "https://nix-amd-ai.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
    ];
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
        server = ./modules/server;
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
        packages = with pkgs; [
          statix
          deadnix
        ];
      };
    };
}
