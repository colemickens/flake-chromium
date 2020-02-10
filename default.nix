let
  pkgset = import (import ./nixpkgs/nixos-unstable) {
    overlays = [
      (self: super: rec {
        chromium-pkgs = self.callPackages ./pkgs/chromium-git {};
      })
    ];
  };
in
  pkgset.chromium-pkgs

