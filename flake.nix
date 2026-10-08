{
  description = "System Consultant Group's headless NixOS router";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    waywarp = {
      url = "github:apersomany/waywarp/v0.1.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      waywarp,
      ...
    }:
    let
      username = "scg";
      userFullName = "System Consultant Group";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.router = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            username
            userFullName
            ;
        };
        modules = [
          { nixpkgs.hostPlatform = system; }
          waywarp.nixosModules.default
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
