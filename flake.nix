{
  description = "chromium";

  inputs = {
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    cachixpkgs = { url = "github:nixos/nixpkgs/nixos-20.03"; };
  };

  outputs = inputs:
    let
      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = genAttrs [ "x86_64-linux" ];

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [];
        };

      variants = 
      let
        pkgs = pkgsFor inputs.nixpkgs "x86_64-linux";
      in system: {
        chromium-dev-ozone = pkgs.chromium.override({
          enableOzone = true;
        });

        chromium-dev-ozone-vaapi = pkgs.chromium.override({
          enableOzone = true;
          useVaapi = true;
        });
      };
    in
    rec {
      devShell = forAllSystems (system:
        (pkgsFor inputs.nixpkgs system).mkShell {
          nativeBuildInputs = with (pkgsFor inputs.nixpkgs system); [
            nixFlakes bash cacert curl git jq openssh ripgrep
            nix-build-uncached
            (pkgsFor inputs.cachixpkgs system).cachix
          ];
        }
      );

      packages = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system);
          attrValues = inputs.nixpkgs.lib.attrValues;
        in (variants system)
      );

      defaultPackage = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system);
          attrValues = inputs.nixpkgs.lib.attrValues;
        in
        nixpkgs_.symlinkJoin {
          name = "flake-chromium";
          paths = attrValues (variants system);
        }
      );
    };
}
