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
  "parse-dockerfile"       # https://github.com/taiki-e/parse-dockerfile
)
descriptions=(
  "Cargo subcommand for testing and continuous integration"
  "Cargo subcommand for LLVM source-based code coverage (-C instrument-coverage)"
  "Cargo subcommand for proper use of -Z minimal-versions"
  "Cargo subcommand for running cargo without dev-dependencies"
  "Simple changelog parser, written in Rust"
  "Dockerfile parser, written in Rust"
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
bail() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::error::%s\n' "$*"
  else
    printf >&2 'error: %s\n' "$*"
  fi
  exit 1
}
info() {
  printf >&2 'info: %s\n' "$*"
}
run_curl() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "$@"
  else
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused \
      "$@"
  fi
}
download_and_verify() {
  local url="$1"
  local out="tools/tmp/cache/${package}/${tag}"
  mkdir -p -- "${out}"
  out="${out}/${url##*/}"
  info "downloading ${url} for verification"
  run_curl -o "${out}" "${url}"
  local sha expected_sha
  sha=$(sha256sum "${out}")
  sha="${sha%% *}"
  expected_sha=$(jq -r '.assets[] | select(.browser_download_url == "'"${url}"'") | .digest' <<<"${api}")
  if [[ "sha256:${sha}" != "${expected_sha}" ]]; then
    bail "digest mismatch for ${url}; expected '${expected_sha}', actual 'sha256:${sha}'"
  fi
  gh release -R "https://github.com/${owner}/${package}" verify "${tag}" >&2
  gh release -R "https://github.com/${owner}/${package}" verify-asset "${tag}" "${out}" >&2
  printf '%s\n' "${sha}"
}

for i in "${!packages[@]}"; do
  package="${packages[${i}]}"
  info "fetching latest version of ${package}"
  api=$(run_curl "https://api.github.com/repos/${owner}/${package}/releases/latest")
  tag=$(jq -r '.tag_name' <<<"${api}")
  x86_64_url="https://github.com/${owner}/${package}/releases/download/${tag}/${package}-x86_64-pc-windows-msvc.zip"
  x86_64_sha=$(download_and_verify "${x86_64_url}")
  aarch64_url="https://github.com/${owner}/${package}/releases/download/${tag}/${package}-aarch64-pc-windows-msvc.zip"
  aarch64_sha=$(download_and_verify "${aarch64_url}")

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
      "hash": "${x86_64_sha}"
    },
    "arm64": {
      "url": "${aarch64_url}",
      "hash": "${aarch64_sha}"
    }
  },
  "bin": "${package}.exe"
}
EOF
done
