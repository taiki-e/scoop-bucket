#!/bin/bash
set -euxo pipefail
IFS=$'\n\t'
cd "$(dirname "$0")"/..

git config user.name "Taiki Endo"
git config user.email "te316e89@gmail.com"

for bucket in bucket/*.json; do
    git add -N "${bucket}"
    if ! git diff --exit-code -- "${bucket}"; then
        name="$(basename "${bucket%.*}")"
        version="$(grep -E '^\s+version "' "${bucket}" | sed -E 's/^\s+version "//' | sed 's/"$//')"
        git add "${bucket}"
        git commit -m "Update ${name} to ${version}"
        has_update=1
    fi
done

if [[ -n "${has_update:-}" ]]; then
    echo "::set-output name=success::false"
fi
