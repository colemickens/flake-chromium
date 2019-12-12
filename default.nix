self: pkgs:
let
chromiumPkgs = {
  # chromium
  chromium-git = (pkgs.callPackages ./pkgs/chromium-git {}).chromium-git;
};
in
  chromiumPkgs // { inherit chromiumPkgs; }

