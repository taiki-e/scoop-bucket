#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: Error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

# Update buckets.
#
# USAGE:
#    ./tools/bucket.sh

owner="taiki-e"
packages=(
    "cargo-hack"             # https://github.com/taiki-e/cargo-hack
    "cargo-llvm-cov"         # https://github.com/taiki-e/cargo-llvm-cov
    "cargo-minimal-versions" # https://github.com/taiki-e/cargo-minimal-versions
    "cargo-no-dev-deps"      # https://github.com/taiki-e/cargo-no-dev-deps
    "parse-changelog"        # https://github.com/taiki-e/parse-changelog
)
descriptions=(
    "Cargo subcommand for testing and continuous integration"
    "Cargo subcommand for LLVM source-based code coverage (-C instrument-coverage)"
    "Cargo subcommand for proper use of -Z minimal-versions"
    "Cargo subcommand for running cargo without dev-dependencies"
    "Simple changelog parser, written in Rust"
)

for i in "${!packages[@]}"; do
    package="${packages[${i}]}"
    set -x
    tag=$(curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://api.github.com/repos/${owner}/${package}/releases/latest" | jq -r '.tag_name')
    x86_64_url="https://github.com/${owner}/${package}/releases/download/${tag}/${package}-x86_64-pc-windows-msvc.zip"
    x86_64_sha="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "${x86_64_url}" | sha256sum)"
    set +x
    aarch64=''
    case "${package}" in
        cargo-llvm-cov) ;; # TODO
        *)
            set -x
            aarch64_url="https://github.com/${owner}/${package}/releases/download/${tag}/${package}-aarch64-pc-windows-msvc.zip"
            aarch64_sha="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "${aarch64_url}" | sha256sum)"
            set +x
            aarch64=",
    \"arm64\": {
      \"url\": \"${aarch64_url}\",
      \"hash\": \"${aarch64_sha%  *}\"
    }"
            ;;
    esac

    # Refs: https://scoop-docs.vercel.app/docs/concepts/App-Manifests.html
    # suggest:vcredist is not needed because their windows binaries are static executables.
    cat >./bucket/"${package}".json <<EOF
{
  "version": "${tag#v}",
  "description": "${descriptions[${i}]}",
  "homepage": "https://github.com/${owner}/${package}",
  "license": "Apache-2.0|MIT",
  "architecture": {
    "64bit": {
      "url": "${x86_64_url}",
      "hash": "${x86_64_sha%  *}"
    }${aarch64}
  },
  "bin": "${package}.exe"
}
EOF
done
