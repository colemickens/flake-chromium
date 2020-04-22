# nixpkgs-chromium

(related: [nixpkgs-wayland](https://github.com/colemickens/nixpkgs-wayland)
and [nixpkgs-graphics](https://github.com/colemickens/nixpkgs-graphics))

## Overview

This is a package-set for NixOS or nixpkgs that contains builds of Chromium for Wayland (aka Chromium built with the X11 and Wayland backends for Ozone).

I will try to update and build this 1-4 times a month. Since this is a package set, at worst you'll have
some local bloat, but you won't ever accidentally have to rebuild chromium like might happen with an overlay.

<img src="./chromium.png" />

## Repo Explanation

In my local checkout, I have volth's `nixpkgs-windows` repo (`chromium-git` branch) cloned in a directory.
I apply/extract the patch `./volth-chromium-git.patch` that makes volth's chromium-git derivation a callable function.

I copy their entire derivation into `./pkgs/chromium-git/vendor-chromium-git`.

`./update-chromium-version.sh` gets the latest tagged release, writes it into `./pkgs/chromium-git/metadata.nix`
and then calls volth's perl script to write out the vendor nix locked deps if it hasn't been made yet.

`./update.sh` updates the nixpkgs ref, calls `./update-chromium-version.sh` and then builds chromium + pushes to cachix.

## Packages

 * `chromium-dev-ozone` - Chromium with Ozone (x11/wayland) and GTK/Glib enabled

## Usage

#### Cachix

See the usage instructions on [nixpkgs-wayland.cachix.org](nixpkgs-wayland.cachix.org) for instructions on how to use the Cachix binary cache so that you don't have to build `chromium-dev-wayland` yourself. (`nixpkgs-wayland` is correct, we're using it for `nixpkgs-chromium` packages as well.)

#### Usage

Quick test:

```nix-env -iA chromium-dev-ozone -f "https://github.com/colemickens/nixpkgs-chromium/archive/master.tar.gz"```

Using in your nixos `configuration.nix`:

```nix
{ pkgs, ...}:

let
  chrpkgsBall = builtins.fetchTarball { url = "https://github.com/colemickens/nixpkgs-chromium/archive/master.tar.gz"; };
  chrpkgs = import chrpkgsBall;
in
{
  config = {
    nix = {
      # this is correct, we're using `nixpkgs-wayland` to cache `nixpkgs-chromium` packages
      binaryCachePublicKeys = [ "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA=" ];
      binaryCaches = [ "https://nixpkgs-wayland.cachix.org" ];
    };

    environment.systemPackages = [ chrpkgs.chromium-dev-ozone ];
  };
}
```

## Credit

Credit to @volth for doing the hard work of writing a `chromium-git` derivation: https://github.com/NixOS/nixpkgs/pull/66438

