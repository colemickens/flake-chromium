# nixpkgs-chromium

(related: [nixpkgs-wayland](https://github.com/colemickens/nixpkgs-wayland)
and [nixpkgs-graphics](https://github.com/colemickens/nixpkgs-graphics))

## Overview

A package-set containing `chromium-git`, a build of Chromium with Ozone (Wayland/X11) enabled.

I will try to build this frequently against `nixos-unstable` to minimize the extra libs on your system, but
since this is a package-set instead of an overlay, you shouldn't be hit with day-long-rebuilds if you happen
to advance the `nixos-unstable` channel before I get a chance to perform a build.

aka, "Chrome on Wayland" for Linux, or at least NixOS users.

## Usage

Quick test:

```nix-env -iA chromium-dev-wayland -f "https://github.com/colemickens/nixpkgs-chromium/archive/master.tar.gz"```

Using in your nixos `configuration.nix`:

```nix
{ pkgs, ...}:

let
  nixpkgsChromiumPkgs = import (builtins.fetchTarball { url = "https://github.com/colemickens/nixpkgs-chromium/archive/master.tar.gz"; }) { pkgs = pkgs; };
in
{
  config = {
    environment.systemPackages = [ nixpkgsChromiumPkgs.chromium-dev-wayland ];
  };
}
```

## Credit

Credit to @volth for doing the hard work of writing a `chromium-git` derivation: https://github.com/NixOS/nixpkgs/pull/66438

