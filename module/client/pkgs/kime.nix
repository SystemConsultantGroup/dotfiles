{
  pkgs,
  kime-src,
  ...
}:
let
  deps = import "${kime-src}/nix/deps.nix" { inherit pkgs; };
  kimeVersion = builtins.readFile "${kime-src}/VERSION";
  inherit (pkgs) llvmPackages_18 rustPlatform qt5;
in
llvmPackages_18.stdenv.mkDerivation {
  pname = "kime";
  version = kimeVersion;
  src = kime-src;
  buildInputs = deps.kimeBuildInputs;
  nativeBuildInputs = deps.kimeNativeBuildInputs ++ [ rustPlatform.cargoSetupHook pkgs.rustc pkgs.cargo ];
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = kime-src;
    hash = "sha256-ZgWHzXixTZWg7+2nXbw2NjeWD/cskGoZ/VSrM7vCwFs=";
  };
  LIBCLANG_PATH = "${llvmPackages_18.libclang.lib}/lib";
  dontUseCmakeConfigure = true;
  dontWrapQtApps = true;
  buildPhase = "bash scripts/build.sh -ar";
  installPhase = ''
    KIME_BIN_DIR=bin \
    KIME_INSTALL_HEADER=1 \
    KIME_INCLUDE_DIR=include \
    KIME_ICON_DIR=share/icons \
    KIME_LIB_DIR=lib \
    KIME_DOC_DIR=share/doc/kime \
    KIME_QT5_DIR=lib/qt-${qt5.qtbase.version} \
    bash scripts/install.sh "$out"
  '';
}
