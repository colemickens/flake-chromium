{ pkgs, stdenv
, wayland, libglvnd, libxkbcommon
, makeWrapper, ed, llvmPackages_10
}:

let
  common =
    (pkgs.callPackages ./vendor-chromium-git {}).chromium-common;

  mkWrappedChromium = { version, llvmPackages, customGnFlags?{}, extraBuildInputs?[] }:
    let chromiumBuild = (common { inherit version llvmPackages customGnFlags extraBuildInputs; }); in
    stdenv.mkDerivation {
      name = "chromium-git-wrapped";
      version = chromiumBuild.version;

      buildInputs = [ makeWrapper ed ];
      outputs = [ "out" ];

      buildCommand =
    let
      libPath = stdenv.lib.makeLibraryPath([]
        #++ stdenv.lib.optional useVaapi libva
        ++ stdenv.lib.optional true libglvnd
      );
    in with stdenv.lib; ''
      mkdir -p "$out/bin"

      eval makeWrapper "${chromiumBuild}/bin/chrome" "$out/bin/chromium"

      ed -v -s "$out/bin/chromium" << EOF
      2i

    '' + stdenv.lib.optionalString (libPath != "") ''
      # To avoid loading .so files from cwd, LD_LIBRARY_PATH here must not
      # contain an empty section before or after a colon.
      export LD_LIBRARY_PATH="\$LD_LIBRARY_PATH\''${LD_LIBRARY_PATH:+:}${libPath}"
    '' + ''

      .
      w
      EOF

      ln -s "$out/bin/chromium" "$out/bin/chromium-browser"

      mkdir -p "$out/share"
      for f in '${chromiumBuild}'/share/*; do # hello emacs */
        ln -s -t "$out/share/" "$f"
      done
    '';
  };
in
  {
    chromium-dev-ozone = mkWrappedChromium {
      version = (import ./metadata.nix).version;
      llvmPackages = llvmPackages_10;
      customGnFlags = {
        # https://cs.chromium.org/chromium/src/docs/ozone_overview.md?type=cs&q=use_glib&sq=package:chromium&g=0&l=293
        use_ozone = true;
        use_system_minigbm = true;
        use_xkbcommon = true;
        use_glib = true;
        use_gtk = true;
        ozone_platform = "wayland";
        ozone_platform_headless = false;
        ozone_platform_wayland = true;
        ozone_platform_x11 = true;
      };
      extraBuildInputs = [
        wayland libglvnd libxkbcommon
      ];
    };
  }

