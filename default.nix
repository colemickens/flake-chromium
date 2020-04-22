let
  pkgset = import (import ./nixpkgs/nixos-unstable) {
    overlays = [
      (self: super: rec {
        inherit (self.callPackages ./pkgs/chromium-git {})
          chromium-dev-ozone;
      })
    ];
  };
in
  pkgset.chromium-dev-ozone
