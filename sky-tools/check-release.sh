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

# Extract strict release versions from fully-qualified refs supplied by git ls-remote.
latest_strict_ref() {
    local prefix="$1"
    awk -v prefix="$prefix" '
        index($2, prefix) == 1 {
            version = substr($2, length(prefix) + 1)
            if (version ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) print version
        }
    ' | LC_ALL=C sort -V | tail -1
}

latest_published_stable_release() {
    local response tag

    command -v curl >/dev/null 2>&1 || die "curl is required for GitHub release metadata"
    command -v python3 >/dev/null 2>&1 || die "python3 is required to parse GitHub release metadata"

    response="$(
        curl --fail --silent --show-error --location \
            -H 'Accept: application/vnd.github+json' \
            "$UPSTREAM_LATEST_PUBLISHED_STABLE_RELEASE_API"
    )" || die "failed to query latest published stable release from ${UPSTREAM_REPOSITORY}"

    tag="$(
        python3 -c '
import json
import sys
payload = json.load(sys.stdin)
if not isinstance(payload, dict) or payload.get("draft") is not False or payload.get("prerelease") is not False:
    raise SystemExit("latest release response is not a published stable release")
tag = payload.get("tag_name")
if not isinstance(tag, str) or not tag:
    raise SystemExit("release response does not contain tag_name")
print(tag)
' <<<"$response"
    )" || die "failed to validate latest published stable release from ${UPSTREAM_REPOSITORY}"

    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        die "latest published stable release tag '${tag}' is not strict vX.Y.Z"
    printf '%s\n' "$tag"
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git worktree"
cd "$repo_root"

git remote get-url "$ORIGIN_REMOTE" >/dev/null 2>&1 || die "remote '$ORIGIN_REMOTE' does not exist"
git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 || die "remote '$UPSTREAM_REMOTE' does not exist"

# git ls-remote only reads remote refs. Do NOT fetch: the repository's existing
# upstream v* tag refspec would otherwise repopulate local tags.
origin_heads="$(git ls-remote --heads "$ORIGIN_REMOTE" 'refs/heads/sky/v*')" ||
    die "failed to read adopted release branches from $ORIGIN_REMOTE"
upstream_tags="$(git ls-remote --refs "$UPSTREAM_REMOTE" 'refs/tags/v*')" ||
    die "failed to read version tags from $UPSTREAM_REMOTE"

LATEST_ADOPTED="$(printf '%s\n' "$origin_heads" | latest_strict_ref 'refs/heads/sky/')"
[[ -n "$LATEST_ADOPTED" ]] || die "no adopted origin/sky/vX.Y.Z branch exists"

HIGHEST_UPSTREAM_TAG="$(printf '%s\n' "$upstream_tags" | latest_strict_ref 'refs/tags/')"
[[ -n "$HIGHEST_UPSTREAM_TAG" ]] || die "upstream contains no strict vX.Y.Z tag"

LATEST_PUBLISHED_STABLE_RELEASE="$(latest_published_stable_release)"
remote_release_tag_sha="$(
    printf '%s\n' "$upstream_tags" |
        awk -v ref="refs/tags/${LATEST_PUBLISHED_STABLE_RELEASE}" '$2 == ref { print $1 }'
)"
[[ -n "$remote_release_tag_sha" ]] ||
    die "published stable tag ${LATEST_PUBLISHED_STABLE_RELEASE} missing from upstream tags"

# A locally cached tag is optional. If present, refuse inconsistent identity.
local_tag_status="NOT_FETCHED"
if git show-ref --verify --quiet "refs/tags/${LATEST_PUBLISHED_STABLE_RELEASE}"; then
    local_sha="$(git rev-parse --verify "refs/tags/${LATEST_PUBLISHED_STABLE_RELEASE}")" ||
        die "could not resolve local ${LATEST_PUBLISHED_STABLE_RELEASE} tag"
    [[ "$local_sha" == "$remote_release_tag_sha" ]] ||
        die "local tag ${LATEST_PUBLISHED_STABLE_RELEASE} differs from upstream"
    local_tag_status="MATCH"
fi

newest="$(printf '%s\n%s\n' "$LATEST_ADOPTED" "$LATEST_PUBLISHED_STABLE_RELEASE" | LC_ALL=C sort -V | tail -1)"
if [[ "$LATEST_ADOPTED" == "$LATEST_PUBLISHED_STABLE_RELEASE" ]]; then
    UPGRADE_AVAILABLE="NO"
elif [[ "$newest" == "$LATEST_PUBLISHED_STABLE_RELEASE" ]]; then
    UPGRADE_AVAILABLE="YES"
else
    die "adopted ${LATEST_ADOPTED} is newer than published ${LATEST_PUBLISHED_STABLE_RELEASE}"
fi

newest="$(printf '%s\n%s\n' "$HIGHEST_UPSTREAM_TAG" "$LATEST_PUBLISHED_STABLE_RELEASE" | LC_ALL=C sort -V | tail -1)"
if [[ "$HIGHEST_UPSTREAM_TAG" == "$LATEST_PUBLISHED_STABLE_RELEASE" ]]; then
    NEWER_TAG_OBSERVED="NO"
elif [[ "$newest" == "$HIGHEST_UPSTREAM_TAG" ]]; then
    NEWER_TAG_OBSERVED="YES"
else
    die "published stable release ${LATEST_PUBLISHED_STABLE_RELEASE} has a newer version than the highest upstream tag ${HIGHEST_UPSTREAM_TAG}"
fi

printf '%-24s : %s\n' 'Adopted release' "$LATEST_ADOPTED"
printf '%-24s : %s\n' 'Published stable release' "$LATEST_PUBLISHED_STABLE_RELEASE"
printf '%-24s : %s\n' 'Highest upstream tag' "$HIGHEST_UPSTREAM_TAG"
printf '%-24s : %s\n' 'Local published tag' "$local_tag_status"
printf '%-24s : %s\n' 'Upgrade available' "$UPGRADE_AVAILABLE"
printf '%-24s : %s\n' 'Newer tag observed' "$NEWER_TAG_OBSERVED"
