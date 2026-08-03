{ pkgs, ... }:
{
  fonts = {
    packages = [
      (pkgs.callPackage ./pkgs/freesentation.nix { })
      pkgs.inter
      pkgs.cascadia-code
      pkgs.nerd-fonts.caskaydia-cove
    ];
    fontconfig = {
      defaultFonts = {
        serif = [
          "Inter"
          "Freesentation"
        ];
        sansSerif = [
          "Inter"
          "Freesentation"
        ];
        monospace = [
          "Cascadia Code"
        ];
      };
      localConf = ''
        <match target="pattern">
          <test name="lang" compare="contains">
            <string>ko</string>
          </test>
          <edit name="family" mode="prepend" binding="strong">
            <string>Freesentation</string>
          </edit>
        </match>
      '';
      useEmbeddedBitmaps = true;
    };
  };
  programs.dconf.enable = true;
}
