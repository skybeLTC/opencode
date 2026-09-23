#!/usr/bin/env bash
set -euo pipefail

ORIGIN_REMOTE="origin"
UPSTREAM_REMOTE="upstream"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

latest_adopted_release() {
    local ref version

    while IFS= read -r ref; do
        version="${ref#${ORIGIN_REMOTE}/sky/}"

        if [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            printf '%s\n' "$version"
        fi
    done < <(
        git for-each-ref \
            --format='%(refname:short)' \
            "refs/remotes/${ORIGIN_REMOTE}/sky/v*"
    )
}

latest_observed_version_tag() {
    local tag

    while IFS= read -r tag; do
        if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            printf '%s\n' "$tag"
        fi
    done < <(git tag -l 'v*')
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
    die "not inside a Git worktree"

cd "$repo_root"

git remote get-url "$ORIGIN_REMOTE" >/dev/null 2>&1 ||
    die "remote '$ORIGIN_REMOTE' does not exist"

git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 ||
    die "remote '$UPSTREAM_REMOTE' does not exist; run sky-tools/setup-local-repo.sh first"

git fetch --quiet "$ORIGIN_REMOTE"
git fetch --quiet "$UPSTREAM_REMOTE"

LATEST_ADOPTED="$(
    latest_adopted_release |
        sort -V |
        tail -1
)"

[[ -n "$LATEST_ADOPTED" ]] ||
    die "no adopted origin/sky/vX.Y.Z branch exists"

HIGHEST_OBSERVED_TAG="$(
    latest_observed_version_tag |
        sort -V |
        tail -1
)"

[[ -n "$HIGHEST_OBSERVED_TAG" ]] ||
    die "no strict vX.Y.Z tag was fetched from upstream"

if [[ "$LATEST_ADOPTED" == "$HIGHEST_OBSERVED_TAG" ]]; then
    NEWER_TAG_OBSERVED="NO"
    RELEASE_REVIEW_REQUIRED="NO"
else
    newest="$(
        printf '%s\n%s\n' \
            "$LATEST_ADOPTED" \
            "$HIGHEST_OBSERVED_TAG" |
            sort -V |
            tail -1
    )"

    if [[ "$newest" == "$HIGHEST_OBSERVED_TAG" ]]; then
        NEWER_TAG_OBSERVED="YES"
        RELEASE_REVIEW_REQUIRED="YES"
    else
        die "latest adopted ${LATEST_ADOPTED} is newer than highest observed upstream tag ${HIGHEST_OBSERVED_TAG}"
    fi
fi

printf 'Latest adopted         : %s\n' "$LATEST_ADOPTED"
printf 'Highest observed tag   : %s\n' "$HIGHEST_OBSERVED_TAG"
printf 'Newer tag observed     : %s\n' "$NEWER_TAG_OBSERVED"
printf 'Release review required: %s\n' "$RELEASE_REVIEW_REQUIRED"
