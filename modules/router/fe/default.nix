{
  lib,
  stdenvNoCC,
  nodejs,
  pnpm,
  pnpmConfigHook,
  fetchPnpmDeps,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "router-fe";
  inherit (lib.importJSON ./package.json) version;
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _:
      !(lib.elem (baseNameOf path) [
        "node_modules"
        "dist"
      ]);
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
  ];
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-jIT60/6WZPUKXZ7Gm5exDmmDkkx/vBmXzQ2QadcAljs=";
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r dist/. "$out/"
    runHook postInstall
  '';
})
