let
  nixosUnstable = import (import ./nixpkgs/nixos-unstable) {};
  pkgset = import ./default.nix { pkgs = nixosUnstable; };
in
  pkgset

