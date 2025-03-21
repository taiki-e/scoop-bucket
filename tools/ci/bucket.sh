#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'
trap -- 's=$?; printf >&2 "%s\n" "${0##*/}:${LINENO}: \`${BASH_COMMAND}\` exit with ${s}"; exit ${s}' ERR
cd -- "$(dirname -- "$0")"/../..

bail() {
  printf >&2 'error: %s\n' "$*"
  exit 1
}

if [[ -z "${CI:-}" ]]; then
  bail "this script is intended to call from release workflow on CI"
fi

git config user.name 'Taiki Endo'
git config user.email 'te316e89@gmail.com'

set -x

has_update=''
for bucket in bucket/*.json; do
  git add -N "${bucket}"
  if ! git diff --exit-code -- "${bucket}" &>/dev/null; then
    name="${bucket##*/}"
    name="${name%.*}"
    version=$(jq -r '.version' "${bucket}")
    git add "${bucket}"
    git commit -m "Update ${name} to ${version}"
    has_update=1
  fi
done

if [[ -n "${has_update}" ]] && [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'success=false\n' >>"${GITHUB_OUTPUT}"
fi
