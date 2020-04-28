#!/usr/bin/env bash
set -x
set -euo pipefail

set +e; version="$(git ls-remote --tag https://github.com/chromium/chromium | cut -d'	' -f2 | \
  rg "refs/tags/(\d+.\d+.\d+.\d+)" -r '$1' | sort -hr | head -1)"; set -e

echo "{ version = \"${version}\"; }" > "./pkgs/chromium-git/metadata.nix"

if [[ ! -f "pkgs/chromium-git/vendor-chromium-git/vendor-${version}.nix" ]]; then
  (cd pkgs/chromium-git/vendor-chromium-git; ./mk-vendor-file.pl "${version}";)
fi

