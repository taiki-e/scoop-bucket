#!/bin/bash
set -euxo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

# shellcheck disable=SC2154
trap 's=$?; echo >&2 "$0: Error on line "${LINENO}": ${BASH_COMMAND}"; exit ${s}' ERR

git config user.name "Taiki Endo"
git config user.email "te316e89@gmail.com"

for bucket in bucket/*.json; do
    git add -N "${bucket}"
    if ! git diff --exit-code -- "${bucket}"; then
        name="$(basename "${bucket%.*}")"
        version="$(jq <"${bucket}" -r '.version')"
        git add "${bucket}"
        git commit -m "Update ${name} to ${version}"
        has_update=1
    fi
done

if [[ -n "${has_update:-}" ]] && [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "success=false" >>"${GITHUB_OUTPUT}"
fi
