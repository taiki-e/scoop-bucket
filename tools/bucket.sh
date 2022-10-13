#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# Update buckets.
#
# USAGE:
#    ./tools/bucket.sh

OWNER="taiki-e"
PACKAGES=(
    "cargo-hack"             # https://github.com/taiki-e/cargo-hack
    "cargo-llvm-cov"         # https://github.com/taiki-e/cargo-llvm-cov
    "cargo-minimal-versions" # https://github.com/taiki-e/cargo-minimal-versions
    "parse-changelog"        # https://github.com/taiki-e/parse-changelog
)
DESCRIPTIONS=(
    "Cargo subcommand for testing and continuous integration"
    "Cargo subcommand for LLVM source-based code coverage (-C instrument-coverage)"
    "Cargo subcommand for proper use of -Z minimal-versions"
    "Simple changelog parser, written in Rust"
)

for i in "${!PACKAGES[@]}"; do
    package="${PACKAGES[${i}]}"
    set -x
    tag=$(curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://api.github.com/repos/${OWNER}/${package}/releases/latest" | jq -r '.tag_name')
    x86_64_url="https://github.com/${OWNER}/${package}/releases/download/${tag}/${package}-x86_64-pc-windows-msvc.zip"
    x86_64_sha="$(curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "${x86_64_url}" | sha256sum)"
    set +x
    aarch64=''
    case "${package}" in
        cargo-llvm-cov | cargo-minimal-versions | parse-changelog) ;;
        *)
            set -x
            aarch64_url="https://github.com/${OWNER}/${package}/releases/download/${tag}/${package}-aarch64-pc-windows-msvc.zip"
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
  "description": "${DESCRIPTIONS[${i}]}",
  "homepage": "https://github.com/${OWNER}/${package}",
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
