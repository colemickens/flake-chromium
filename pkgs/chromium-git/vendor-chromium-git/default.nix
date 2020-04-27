{ stdenv, stdenvNoCC, lib, fetchgit, fetchurl, runCommand, buildPackages, git
, python2, ninja, llvmPackages_9, llvmPackages_10, bison, gperf, pkg-config
, dbus, systemd, glibc, at-spi2-atk, atk, at-spi2-core, nspr, nss, pciutils, utillinux, kerberos, gdk-pixbuf
, gnome2, glib, gtk2, gtk3, cups, libgcrypt, alsaLib, pulseaudio, xdg_utils, libXScrnSaver, libXcursor, libXtst, libGLU, libGL, libXdamage
}:

let
  # Serialize Nix types into GN types according to this document:
  # https://gn.googlesource.com/gn/+/refs/heads/master/docs/language.md
  gnToString =
    let
      mkGnString = value: "\"${lib.escape ["\"" "$" "\\"] value}\"";
      sanitize = value:
        if value == true then "true"
        else if value == false then "false"
        else if lib.isList value then "[${lib.concatMapStringsSep ", " sanitize value}]"
        else if lib.isInt value then toString value
        else if lib.isString value then mkGnString value
        else throw "Unsupported type for GN value `${value}'.";
      toFlag = key: value: "${key}=${sanitize value}";
    in
      attrs: lib.concatStringsSep " " (lib.attrValues (lib.mapAttrs toFlag attrs));

  # https://gitlab.com/noencoding/OS-X-Chromium-with-proprietary-codecs/wikis/List-of-all-gn-arguments-for-Chromium-build
  defaultGnFlags = {
    is_debug = false;
    use_jumbo_build = false; # `true` gives at least 2X compilation speedup, but it does not work for some versions

    enable_nacl = false;
    is_component_build = false;
    is_clang = true;
    clang_use_chrome_plugins = false;

    # Google API keys, see:
    #   http://www.chromium.org/developers/how-tos/api-keys
    # Note: These are for NixOS/nixpkgs use ONLY. For your own distribution,
    # please get your own set of keys.
    google_api_key = "AIzaSyDGi15Zwl11UNe6Y-5XW_upsfyw31qwZPI";
    google_default_client_id = "404761575300.apps.googleusercontent.com";
    google_default_client_secret = "9rIFQjfnkykEmqb6FfjJQD1D";

    linux_use_bundled_binutils = false;
    treat_warnings_as_errors = false;
    use_sysroot = false;
    use_cups = true;
    use_gio = true;
    use_gnome_keyring = false;
    use_lld = false;
    use_gold = false;
    use_pulseaudio = true;
    link_pulseaudio = defaultGnFlags.use_pulseaudio;
    enable_widevine = false;
    enable_swiftshader = false;
    closure_compile = false; # Disable type-checking for the Web UI to avoid a Java dependency.

    # enable support for the H.264 codec
    proprietary_codecs = true;
    ffmpeg_branding = "Chrome";

    # explicit host_cpu and target_cpu prevent "nix-shell pkgsi686Linux.chromium-git" from building x86_64 version
    # there is no problem with nix-build, but platform detection in nix-shell is not correct
    host_cpu   = { i686-linux = "x86"; x86_64-linux = "x64"; armv7l-linux = "arm"; aarch64-linux = "arm64"; }.${stdenv.buildPlatform.system};
    target_cpu = { i686-linux = "x86"; x86_64-linux = "x64"; armv7l-linux = "arm"; aarch64-linux = "arm64"; }.${stdenv.hostPlatform.system};
  };

  common = { version, llvmPackages, customGnFlags?{}, extraBuildInputs?[] }:
    let
      gnFlags = defaultGnFlags // customGnFlags;
      deps = import (./vendor- + version + ".nix") { inherit fetchgit fetchurl runCommand buildPackages; };
      src = stdenvNoCC.mkDerivation rec {
        name = "chromium-${version}-src";
        buildCommand =
          # <nixpkgs/pkgs/build-support/trivial-builders.nix>'s `linkFarm` or `buiildEnv` would work here if they supported nested paths
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (path: src: ''
                                    echo "$out/${path}"
                                    if [ -d "${src}" ]; then
                                      mkdir -p         "$out/${path}"
                                      cp -r "${src}/." "$out/${path}"
                                      chmod -R u+w     "$out/${path}"
                                    elif [ -f "${src}" ]; then
                                      install -D "${src}" "$out/${path}"
                                    else
                                      exit 1
                                    fi
                                '') deps
          ) +
          # introduce files missing in git repos
          ''
            echo 'LASTCHANGE=${deps."src".rev}-refs/heads/master@{#0}'             > $out/src/build/util/LASTCHANGE
            echo '1555555555'                                                      > $out/src/build/util/LASTCHANGE.committime

            echo '/* Generated by lastchange.py, do not edit.*/'                   > $out/src/gpu/config/gpu_lists_version.h
            echo '#ifndef GPU_CONFIG_GPU_LISTS_VERSION_H_'                        >> $out/src/gpu/config/gpu_lists_version.h
            echo '#define GPU_CONFIG_GPU_LISTS_VERSION_H_'                        >> $out/src/gpu/config/gpu_lists_version.h
            echo '#define GPU_LISTS_VERSION "${deps."src".rev}"'                  >> $out/src/gpu/config/gpu_lists_version.h
            echo '#endif  // GPU_CONFIG_GPU_LISTS_VERSION_H_'                     >> $out/src/gpu/config/gpu_lists_version.h

            echo '/* Generated by lastchange.py, do not edit.*/'                   > $out/src/skia/ext/skia_commit_hash.h
            echo '#ifndef SKIA_EXT_SKIA_COMMIT_HASH_H_'                           >> $out/src/skia/ext/skia_commit_hash.h
            echo '#define SKIA_EXT_SKIA_COMMIT_HASH_H_'                           >> $out/src/skia/ext/skia_commit_hash.h
            echo '#define SKIA_COMMIT_HASH "${deps."src/third_party/skia".rev}-"' >> $out/src/skia/ext/skia_commit_hash.h
            echo '#endif  // SKIA_EXT_SKIA_COMMIT_HASH_H_'                        >> $out/src/skia/ext/skia_commit_hash.h
          '';
      };
    in stdenv.mkDerivation rec {
      pname = "chromium-git";
      inherit version src;

      nativeBuildInputs = [ ninja python2 pkg-config gperf bison git ]
        ++ lib.optional (lib.versionAtLeast version "83") python2.pkgs.setuptools;

      buildInputs = [
        dbus at-spi2-atk atk at-spi2-core nspr nss pciutils utillinux kerberos
        gdk-pixbuf glib gtk3 alsaLib libXScrnSaver libXcursor libXtst libGLU libGL libXdamage
      ] ++ lib.optionals (lib.versionOlder version "65.0") [
        gnome2.GConf gtk2
      ] ++ lib.optionals gnFlags.use_cups [
        cups libgcrypt
      ] ++ lib.optionals gnFlags.use_pulseaudio [
        pulseaudio
      ] ++ extraBuildInputs;

      postPatch = ''
        ( cd src
          # We want to be able to specify where the sandbox is via CHROME_DEVEL_SANDBOX
          substituteInPlace sandbox/linux/suid/client/setuid_sandbox_host.cc \
            --replace \
              'return sandbox_binary;' \
              'return base::FilePath(GetDevelSandboxPath());'

          for f in services/audio/audio_sandbox_hook_linux.cc ; do
            if [ -f "$f" ]; then
              echo "postPatch: patching $f"
              sed -i.bak -e 's|".*/gconv/|"${glibc}/lib/gconv/|'            \
                         -e 's|".*/share/alsa/|"${alsaLib}/share/alsa/|'    \
                         -e 's|".*/share/locale/|"${glibc}/share/locale/|'  "$f"
              git diff --no-index --  $f.bak $f || true
            else
              echo "postPatch: $f does not exist"
            fi
          done

          for f in chrome/browser/shell_integration_linux.cc ; do
            if [ -f "$f" ]; then
              echo "postPatch: patching $f"
              sed -i.bak -e 's@"\(#!\)\?.*xdg-@"\1${xdg_utils}/bin/xdg-@' "$f"
              git diff --no-index --  $f.bak $f || true
            else
              echo "postPatch: $f does not exist"
            fi
          done

          for f in device/udev_linux/udev?_loader.cc ; do
            echo "postPatch: patching $f"
            sed -i.bak -e 's!"[^"]*libudev\.so!"${systemd.lib}/lib/libudev.so!' "$f"
            git diff --no-index --  $f.bak $f || true
          done

          for f in gpu/config/gpu_info_collector_linux.cc \
                   third_party/angle/src/gpu_info_util/SystemInfo_libpci.cpp \
                   ios/third_party/webkit/src/Source/ThirdParty/ANGLE/src/gpu_info_util/SystemInfo_libpci.cpp ; do
            if [ -f "$f" ]; then
              echo "postPatch: patching $f"
              sed -i.bak -e 's!"[^"]*libpci\.so!"${pciutils}/lib/libpci.so!' "$f"
              git diff --no-index --  $f.bak $f || true
            else
              echo "postPatch: $f does not exist"
            fi
          done

          # Allow to put extensions into the system-path.
          for f in chrome/common/chrome_paths.cc ; do
            if [ -f "$f" ]; then
              sed -i.bak -e 's,/usr,/run/current-system/sw,' chrome/common/chrome_paths.cc
              git diff --no-index --  $f.bak $f || true
            else
              echo "postPatch: $f does not exist"
            fi
          done

          ${lib.optionalString stdenv.isAarch64 ''
              substituteInPlace build/toolchain/linux/BUILD.gn \
                --replace 'toolprefix = "aarch64-linux-gnu-"' 'toolprefix = ""'
           ''}

          patchShebangs --build .

          mkdir -p buildtools/linux64
          ln -s --force ${llvmPackages.clang.cc}/bin/clang-format      buildtools/linux64/clang-format                     || true

          mkdir -p third_party/llvm-build/Release+Asserts/bin
          ln -s --force ${llvmPackages.clang}/bin/clang                third_party/llvm-build/Release+Asserts/bin/clang    || true
          ln -s --force ${llvmPackages.clang}/bin/clang++              third_party/llvm-build/Release+Asserts/bin/clang++  || true
          ln -s --force ${llvmPackages.llvm}/bin/llvm-ar               third_party/llvm-build/Release+Asserts/bin/llvm-ar  || true

          echo 'build_with_chromium = true'                > build/config/gclient_args.gni
          echo 'checkout_android = false'                 >> build/config/gclient_args.gni
          echo 'checkout_android_native_support = false'  >> build/config/gclient_args.gni
          echo 'checkout_nacl = false'                    >> build/config/gclient_args.gni
          echo 'checkout_openxr = false'                  >> build/config/gclient_args.gni
          echo 'checkout_oculus_sdk = false'              >> build/config/gclient_args.gni
          echo 'checkout_google_benchmark = false'        >> build/config/gclient_args.gni
          echo 'checkout_libaom = false'                  >> build/config/gclient_args.gni
        )
      '';

      configurePhase = ''
        # attept to fix python2 failing with "EOFError: EOF read where object expected" on multi-core builders
        export PYTHONDONTWRITEBYTECODE=true
        ( cd src
          buildtools/linux64/gn gen ${lib.escapeShellArg "--args=${gnToString gnFlags}"} out/Release
        )
      '';

      buildPhase = ''
        ( cd src
          ninja -C out/Release chrome
        )
      '';

      installPhase = ''
        ( cd src/out/Release
          mkdir -p locales resources extensions   # the directories are optional, ensure they exist for following `cp` success

          mkdir -p $out/bin
          cp -r chrome locales resources extensions *.so *.pak *.dat *.bin $out/bin/
        )
      '';

      meta = with stdenv.lib; {
        description = "An open source web browser from Google";
        homepage = https://github.com/chromium/chromium;
        license = licenses.bsd3;
        platforms = [ "i686-linux" "armv7l-linux" "x86_64-linux" "aarch64-linux" ];
        maintainers = with maintainers; [ volth ];
      };
    };

in {
  chromium-common = common;
  chromium-git_78 = common { version = "78.0.3905.1"  ; llvmPackages = llvmPackages_9;  };
  chromium-git_79 = common { version = "79.0.3945.147"; llvmPackages = llvmPackages_9;  };
  chromium-git_80 = common { version = "80.0.3987.163"; llvmPackages = llvmPackages_9;  };
  chromium-git_81 = common { version = "81.0.4044.118"; llvmPackages = llvmPackages_9;  };
  chromium-git_82 = common { version = "82.0.4085.28" ; llvmPackages = llvmPackages_10; };
  chromium-git_83 = common { version = "83.0.4103.18" ; llvmPackages = llvmPackages_10; };
  chromium-git_84 = common { version = "84.0.4118.0"  ; llvmPackages = llvmPackages_10; };
}