#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

BASE_TAG="$(
    git describe \
        --tags \
        --match 'v[0-9]*.[0-9]*.[0-9]*' \
        --abbrev=0
)"

COMMIT="$(git rev-parse --short=10 HEAD)"
VERSION="${BASE_TAG#v}-sky.${COMMIT}"

if ! git diff --quiet || ! git diff --cached --quiet; then
    VERSION="${VERSION}.dirty"
fi

echo "OpenCode local build"
echo "  base    : ${BASE_TAG}"
echo "  commit  : ${COMMIT}"
echo "  version : ${VERSION}"
echo

OPENCODE_VERSION="${VERSION}" \
    ./packages/opencode/script/build.ts --single
