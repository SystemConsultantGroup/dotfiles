{
  description = "System Consultant Group's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kime.url = "github:apersomany/kime";
    nixos-router = {
      url = "github:chayleaf/nixos-router";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notnft = {
      url = "github:chayleaf/notnft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents-nix.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-router,
      notnft,
      llm-agents-nix,
      ...
    }@inputs:
    let
      username = "scg";
      userFullName = "System Consultant Group";
      gitUserName = "scg";
      gitUserEmail = "scg@scg.skku.ac.kr";
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      mkHost =
        name: extraModules:
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
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations = {
        router = mkHost "router" [
          nixos-router.nixosModules.default
          notnft.nixosModules.default
        ];
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
        packages = [
          pkgs.treefmt
          pkgs.nil
          pkgs.nixd
          pkgs.statix
          pkgs.deadnix
          pkgs.direnv
        ];
      };
    };
}
