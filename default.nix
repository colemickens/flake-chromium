{ pkgs }:

let
  c = pkgs.callPackages ./pkgs/chromium-git {};
in
  {
    chromium-dev-wayland = c.chromium-git-wayland;
    chromium-dev-wayland-gtk = c.chromium-git-wayland-gtk;
  }

