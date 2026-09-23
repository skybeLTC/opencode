#!/usr/bin/env bash
set -euo pipefail

ORIGIN_REMOTE="origin"
UPSTREAM_REMOTE="upstream"
UPSTREAM_REPOSITORY="anomalyco/opencode"
UPSTREAM_LATEST_PUBLISHED_STABLE_RELEASE_API="https://api.github.com/repos/${UPSTREAM_REPOSITORY}/releases/latest"

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

highest_observed_version_tag() {
    local tag

    while IFS= read -r tag; do
        if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            printf '%s\n' "$tag"
        fi
    done < <(git tag -l 'v*')
}

latest_published_stable_release() {
    local response tag

    command -v curl >/dev/null 2>&1 ||
        die "curl is required to query the upstream published stable release"

    command -v python3 >/dev/null 2>&1 ||
        die "python3 is required to parse the upstream published stable release response"

    response="$(
        curl \
            --fail \
            --silent \
            --show-error \
            --location \
            -H 'Accept: application/vnd.github+json' \
            "$UPSTREAM_LATEST_PUBLISHED_STABLE_RELEASE_API"
    )" || die "failed to query latest published stable release from ${UPSTREAM_REPOSITORY}"

    tag="$(
        python3 -c '
import json
import sys

payload = json.load(sys.stdin)
tag = payload.get("tag_name")
if not isinstance(tag, str) or not tag:
    raise SystemExit("release response does not contain tag_name")
print(tag)
' <<<"$response"
    )" || die "failed to parse latest published stable release from ${UPSTREAM_REPOSITORY}"

    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "latest published stable release tag '${tag}' is not strict vX.Y.Z"

    printf '%s\n' "$tag"
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
    highest_observed_version_tag |
        sort -V |
        tail -1
)"

[[ -n "$HIGHEST_OBSERVED_TAG" ]] ||
    die "no strict vX.Y.Z tag was fetched from upstream"

LATEST_PUBLISHED_STABLE_RELEASE="$(latest_published_stable_release)"

upstream_published_release_tag_sha="$(
    git ls-remote \
        --refs \
        "$UPSTREAM_REMOTE" \
        "refs/tags/${LATEST_PUBLISHED_STABLE_RELEASE}" |
        awk 'NR == 1 { print $1 }'
)" || die "failed to resolve published stable release tag ${LATEST_PUBLISHED_STABLE_RELEASE} from upstream"

[[ -n "$upstream_published_release_tag_sha" ]] ||
    die "published stable release tag ${LATEST_PUBLISHED_STABLE_RELEASE} does not exist on upstream"

local_published_release_tag_sha="$(
    git rev-parse --verify "refs/tags/${LATEST_PUBLISHED_STABLE_RELEASE}" 2>/dev/null
)" || die "published stable release tag ${LATEST_PUBLISHED_STABLE_RELEASE} was not fetched from upstream"

[[ "$local_published_release_tag_sha" == "$upstream_published_release_tag_sha" ]] ||
    die "local published stable release tag ${LATEST_PUBLISHED_STABLE_RELEASE} does not match upstream"

if [[ "$LATEST_ADOPTED" == "$LATEST_PUBLISHED_STABLE_RELEASE" ]]; then
    UPGRADE_AVAILABLE="NO"
else
    newest="$(
        printf '%s\n%s\n' \
            "$LATEST_ADOPTED" \
            "$LATEST_PUBLISHED_STABLE_RELEASE" |
            sort -V |
            tail -1
    )"

    if [[ "$newest" == "$LATEST_PUBLISHED_STABLE_RELEASE" ]]; then
        UPGRADE_AVAILABLE="YES"
    else
        die "latest adopted ${LATEST_ADOPTED} is newer than latest published stable release ${LATEST_PUBLISHED_STABLE_RELEASE}"
    fi
fi

if [[ "$HIGHEST_OBSERVED_TAG" == "$LATEST_PUBLISHED_STABLE_RELEASE" ]]; then
    NEWER_TAG_OBSERVED="NO"
else
    newest="$(
        printf '%s\n%s\n' \
            "$LATEST_PUBLISHED_STABLE_RELEASE" \
            "$HIGHEST_OBSERVED_TAG" |
            sort -V |
            tail -1
    )"

    if [[ "$newest" == "$HIGHEST_OBSERVED_TAG" ]]; then
        NEWER_TAG_OBSERVED="YES"
    else
        die "latest published stable release ${LATEST_PUBLISHED_STABLE_RELEASE} is newer than highest observed tag ${HIGHEST_OBSERVED_TAG}"
    fi
fi

printf '%-24s : %s\n' 'Adopted release' "$LATEST_ADOPTED"
printf '%-24s : %s\n' 'Published stable release' "$LATEST_PUBLISHED_STABLE_RELEASE"
printf '%-24s : %s\n' 'Highest observed tag' "$HIGHEST_OBSERVED_TAG"
printf '%-24s : %s\n' 'Upgrade available' "$UPGRADE_AVAILABLE"
printf '%-24s : %s\n' 'Newer tag observed' "$NEWER_TAG_OBSERVED"
