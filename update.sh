#!/usr/bin/env bash

set -euo pipefail
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# keep track of what we build for the README
pkgentries=(); nixpkgentries=();
cache="nixpkgs-wayland";
build_attr="${1:-"waylandPkgs"}"

up=0 # updated_performed # up=$(( $up + 1 ))

export NIX_PATH="nixpkgs=https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz"

function update() {
  typ="${1}"
  pkg="${2}"

  metadata="${pkg}/metadata.nix"
  pkgname="$(basename "${pkg}")"

  branch="$(nix-instantiate "${metadata}" --eval --json -A branch | jq -r .)"
  rev="$(nix-instantiate "${metadata}" --eval --json -A rev | jq -r .)"
  date="$(nix-instantiate "${metadata}" --eval --json -A revdate | jq -r .)"
  sha256="$(nix-instantiate "${metadata}" --eval --json -A sha256 | jq -r .)"
  upattr="$(nix-instantiate "${metadata}" --eval --json -A upattr | jq -r . || echo "\"${pkgname}\"" | jq -r .)"
  url="$(nix-instantiate "${metadata}" --eval --json -A url | jq -r . || echo "\"\"" | jq -r .)"
  skip="$(nix-instantiate "${metadata}" --eval --json -A skip | jq -r . || echo "false" | jq -r .)"

  newdate="${date}"
  if [[ "${skip}" != "true" ]]; then
    # Determine RepoTyp (git/hg)
    if   nix-instantiate "${metadata}" --eval --json -A repo_git; then repotyp="git";
    elif nix-instantiate "${metadata}" --eval --json -A repo_hg; then repotyp="hg";
    else echo "unknown repo_typ" && exit -1;
    fi

    # Update Rev
    if [[ "${repotyp}" == "git" ]]; then
      repo="$(nix-instantiate "${metadata}" --eval --json -A repo_git | jq -r .)"
      newrev="$(git ls-remote "${repo}" "${branch}" | awk '{ print $1}')"
    elif [[ "${repotyp}" == "hg" ]]; then
      repo="$(nix-instantiate "${metadata}" --eval --json -A repo_hg | jq -r .)"
      newrev="$(hg identify "${repo}" -r "${branch}")"
    fi

    if [[ "${rev}" != "${newrev}" ]]; then
      up=$(( $up + 1 ))

      # Update RevDate
      d="$(mktemp -d)"
      if [[ "${repotyp}" == "git" ]]; then
        git clone -b "${branch}" --single-branch --depth=1 "${repo}" "${d}"
        newdate="$(cd "${d}"; git log --format=%ci --max-count=1)"
      elif [[ "${repotyp}" == "hg" ]]; then
        hg clone "${repo}#${branch}" "${d}"
        newdate="$(cd "${d}"; hg log -r1 --template '{date|isodate}')"
      fi
      rm -rf "${d}"

      # Update Sha256
      if [[ "${typ}" == "pkgs" ]]; then
        newsha256="$(nix-prefetch --output raw \
            -E "(import ./build.nix).${upattr}" \
            --rev "${newrev}")"
      elif [[ "${typ}" == "nixpkgs" ]]; then
        newsha256="$(nix-prefetch-url --unpack "${url}")"
      fi

      # TODO: do this with nix instead of sed?
      sed -i "s/${rev}/${newrev}/" "${metadata}"
      sed -i "s/${date}/${newdate}/" "${metadata}"
      sed -i "s/${sha256}/${newsha256}/" "${metadata}"
    fi
  fi

  if [[ "${skip}" == "true" ]]; then
    newdate="${newdate} (pinned)"
  fi
  if [[ "${typ}" == "pkgs" ]]; then
    # TODO: Remove usage of Nix CLI v2
    desc="$(nix eval --raw "(import ./build.nix).${upattr}.meta.description")"
    home="$(nix eval --raw "(import ./build.nix).${upattr}.meta.homepage")"
    pkgentries=("${pkgentries[@]}" "| [${pkgname}](${home}) | ${newdate} | ${desc} |");
  elif [[ "${typ}" == "nixpkgs" ]]; then
    nixpkgentries=("${nixpkgentries[@]}" "| ${pkgname} | ${newdate} |");
  fi
}

for p in nixpkgs/*; do
  update "nixpkgs" "${p}"
done

rm -rf ./pkgs/chromium-git/vendor-chromium-git
cp -a ./nixpkgs-windows/pkgs/applications/networking/browsers/chromium-git \
  ./pkgs/chromium-git/vendor-chromium-git
(cd ./nixpkgs-windows; git format-patch -1 --stdout > ../volth-chromium-git.patch)

cachix push -w "${cache}" &
CACHIX_PID="$!"
trap "kill ${CACHIX_PID}" EXIT

nix-build \
  --no-out-link --keep-going \
  | cachix push "${cache}"

