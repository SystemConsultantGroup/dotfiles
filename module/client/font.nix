{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = [
      (pkgs.callPackage ./pkgs/freesentation.nix { })
      pkgs.inter
      pkgs.cascadia-code
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
      subpixel = {
        lcdfilter = "default";
        rgba = "rgb";
      };
    };
  };
  programs.dconf.profiles.user = {
    enableUserDb = true;
    databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            font-name = "Inter 11";
            font-antialiasing = "rgba";
            font-hinting = "slight";
            font-rgba-order = "rgb";
          };
        };
      }
    ];
  };
}
