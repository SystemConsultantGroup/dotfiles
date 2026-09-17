{
  description = "System Consultant Group's headless NixOS router";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-router = {
      url = "github:chayleaf/nixos-router";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    notnft = {
      url = "github:chayleaf/notnft";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-router,
      notnft,
      ...
    }:
    let
      username = "scg";
      userFullName = "System Consultant Group";
      gitUserName = "scg";
      gitUserEmail = "scg@scg.skku.ac.kr";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.router = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            username
            userFullName
            gitUserName
            gitUserEmail
            ;
          notnft = notnft.lib.${system};
        };
        modules = [
          { nixpkgs.hostPlatform = system; }
          nixos-router.nixosModules.default
          notnft.nixosModules.default
          ./hosts/router/configuration.nix
        ];
      };

      formatter.${system} = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [
          pkgs.treefmt
          pkgs.nixfmt
        ];
        text = ''
          exec treefmt "$@"
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
