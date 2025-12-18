{
  pkgs,
  fetchurl,
  unzip,
  ...
}:
pkgs.stdenv.mkDerivation rec {
  pname = "freesentation";
  version = "2.001";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/Freesentation/freesentation/refs/heads/main/Freesentation-${version}.zip";
    sha256 = "sha256-c8hZyUTJfaxjktpVIKMDQUEmt36lIjWOPOUT7zGqzYQ=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm644 *.ttf -t $out/share/fonts/truetype/

    runHook postInstall
  '';

  meta = {
    description = "Freesentation Font";
    homepage = "https://github.com/Freesentation/freesentation";
  };
}
