{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "router-be";
  inherit ((builtins.fromTOML (builtins.readFile ./Cargo.toml)).package) version;
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _: baseNameOf path != "target";
  };
  cargoLock.lockFile = ./Cargo.lock;
  meta.mainProgram = "router-be";
}
