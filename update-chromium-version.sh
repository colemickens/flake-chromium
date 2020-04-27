#!/usr/bin/env bash
set -x
set -euo pipefail

# get the thing from the git tag (find old code for this)

# ./mk-vendor.pl

set +e; version="$(git ls-remote --tag https://github.com/chromium/chromium | cut -d'	' -f2 | \
  rg "refs/tags/(\d+.\d+.\d+.\d+)" -r '$1' | sort -hr | head -1)"; set -e

./pkgs/chromium-git/vendor-chromium-git/mk-vendor-file.pl "${version}"

