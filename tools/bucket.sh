#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/..

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

retry() {
  for i in {1..10}; do
    if "$@"; then
      return 0
    else
      sleep "${i}"
    fi
  done
  "$@"
}
info() {
  printf >&2 'info: %s\n' "$*"
}
run_curl() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      "$@"
  else
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused \
      "$@"
  fi
}

for i in "${!packages[@]}"; do
  package="${packages[${i}]}"
  info "fetching latest version of ${package}"
  tag=$(run_curl "https://api.github.com/repos/${owner}/${package}/releases/latest" | jq -r '.tag_name')
  x86_64_url="https://github.com/${owner}/${package}/releases/download/${tag}/${package}-x86_64-pc-windows-msvc.zip"
  info "downloading ${x86_64_url} for checksum"
  x86_64_sha=$(run_curl "${x86_64_url}" | sha256sum)
  aarch64=''
  case "${package}" in
    cargo-llvm-cov) ;; # TODO
    *)
      aarch64_url="https://github.com/${owner}/${package}/releases/download/${tag}/${package}-aarch64-pc-windows-msvc.zip"
      info "downloading ${aarch64_url} for checksum"
      aarch64_sha=$(run_curl "${aarch64_url}" | sha256sum)
      aarch64=",
    \"arm64\": {
      \"url\": \"${aarch64_url}\",
      \"hash\": \"${aarch64_sha%% *}\"
    }"
      ;;
  esac

  # Refs: https://scoop-docs.vercel.app/docs/concepts/App-Manifests.html
  # suggest:vcredist is not needed because their windows binaries are static executables.
  cat >|./bucket/"${package}".json <<EOF
{
  "version": "${tag#v}",
  "description": "${descriptions[${i}]}",
  "homepage": "https://github.com/${owner}/${package}",
  "license": "Apache-2.0|MIT",
  "architecture": {
    "64bit": {
      "url": "${x86_64_url}",
      "hash": "${x86_64_sha%% *}"
    }${aarch64}
  },
  "bin": "${package}.exe"
}
EOF
done
