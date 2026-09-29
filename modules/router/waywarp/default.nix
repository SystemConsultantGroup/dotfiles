# Staging import for the Waywarp NixOS module.
#
# module.nix is vendored verbatim from
# https://gist.github.com/apersomany/df14b8e24fb8f96b0aaab6705483bde2 so it can
# be diffed against upstream. Replace this file with the flake's nixosModule
# once Waywarp is published.
#
# No package is available yet, so the default package throws on use. Defining
# any instance before setting services.waywarp.package fails evaluation rather
# than producing a system that cannot start.
import ./module.nix {
  self.packages = throw "services.waywarp.package must be set until the Waywarp flake is published";
}
