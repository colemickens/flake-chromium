#! /usr/bin/env nix-shell
#! nix-shell -i bash ./shell.nix
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -euo pipefail
set -x

cache="nixpkgs-wayland"

oldversion="$(cat latest.json | jq -r '.cachedInfo.chksum' |  grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')"
rm -rf ./.ci/commit-message

nix flake --experimental-features 'nix-command flakes' \
  update \
    --update-input nixpkgs \
    --update-input mozilla

nix --experimental-features 'nix-command flakes' \
  eval --impure '.#latest' --json \
    | jq > latest.json

out="$(set -eu; nix --experimental-features 'nix-command flakes' --pure-eval eval --raw ".#")"
drv="$(set -euo pipefail; nix --experimental-features 'nix-command flakes' --pure-eval show-derivation "${out}" | jq -r 'to_entries[].key')"
echo -e "${drv}"

nix-build-uncached \
  --option "extra-binary-caches" "https://cache.nixos.org https://nixpkgs-wayland.cachix.org" \
  --option "trusted-public-keys" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA=" \
  --option "build-cores" "0" \
  --option "narinfo-cache-negative-ttl" "0" \
  --keep-going --no-out-link ${drv} | cachix push "${cache}"

newversion="$(cat latest.json | jq -r '.cachedInfo.chksum' |  grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}')"
if [[ "${newversion}" != "${oldversion}" ]]; then
  commitmsg="firefox-nightly-bin: ${oldversion} -> ${newversion}"
  echo -e "${commitmsg}" > .ci/commit-message
else
  echo "nothing to do, there was no version bump"
fi
