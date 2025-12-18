{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      (callPackage ./pkgs/freesentation.nix { })
      inter
      cascadia-code
    ];
    fontconfig = {
      defaultFonts = {
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
