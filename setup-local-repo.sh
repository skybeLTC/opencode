#!/usr/bin/env bash
set -euo pipefail

ORIGIN_REMOTE="origin"
UPSTREAM_REMOTE="upstream"
UPSTREAM_URL="git@github.com:anomalyco/opencode.git"
TARGET_BRANCH="${1:-}"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
    die "not inside a Git worktree"

cd "$repo_root"

git remote get-url "$ORIGIN_REMOTE" >/dev/null 2>&1 ||
    die "remote '$ORIGIN_REMOTE' does not exist; clone the Sky fork first"

origin_url="$(git remote get-url "$ORIGIN_REMOTE")"

info "Sky OpenCode repository bootstrap"
info "  repository : $repo_root"
info "  origin     : $origin_url"
info "  upstream   : $UPSTREAM_URL"
if [[ -n "$TARGET_BRANCH" ]]; then
    info "  target     : $TARGET_BRANCH"
else
    info "  target     : <none>"
fi
info ""

if [[ -n "$TARGET_BRANCH" ]] &&
   [[ ! "$TARGET_BRANCH" =~ ^sky/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "target branch must match sky/vX.Y.Z"
fi

# Keep the clone's origin URL/transport, but replace its fetch policy.
git config --unset-all "remote.${ORIGIN_REMOTE}.fetch" 2>/dev/null || true
git config --add "remote.${ORIGIN_REMOTE}.fetch" \
    '+refs/heads/main:refs/remotes/origin/main'
git config --add "remote.${ORIGIN_REMOTE}.fetch" \
    '+refs/heads/sky/*:refs/remotes/origin/sky/*'
git config "remote.${ORIGIN_REMOTE}.tagOpt" --no-tags

# upstream is repository policy, so normalize its URL and fetch policy.
if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    git remote set-url "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
else
    git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

git config --unset-all "remote.${UPSTREAM_REMOTE}.fetch" 2>/dev/null || true
git config --add "remote.${UPSTREAM_REMOTE}.fetch" \
    '+refs/heads/dev:refs/remotes/upstream/dev'
git config --add "remote.${UPSTREAM_REMOTE}.fetch" \
    'refs/tags/v*:refs/tags/v*'
git config "remote.${UPSTREAM_REMOTE}.tagOpt" --no-tags

info "Fetching origin..."
git fetch "$ORIGIN_REMOTE"

info "Fetching upstream..."
git fetch "$UPSTREAM_REMOTE"

if [[ -n "$TARGET_BRANCH" ]]; then
    base_tag="${TARGET_BRANCH#sky/}"

    git show-ref --verify --quiet "refs/remotes/origin/${TARGET_BRANCH}" ||
        die "origin/${TARGET_BRANCH} does not exist"

    git show-ref --verify --quiet "refs/tags/${base_tag}" ||
        die "base tag ${base_tag} was not fetched from upstream"

    if git show-ref --verify --quiet "refs/heads/${TARGET_BRANCH}"; then
        git switch "$TARGET_BRANCH"
    else
        git switch -c "$TARGET_BRANCH" "origin/${TARGET_BRANCH}"
    fi

    git branch --set-upstream-to="origin/${TARGET_BRANCH}" \
        "$TARGET_BRANCH" >/dev/null

    git merge-base --is-ancestor "$base_tag" "$TARGET_BRANCH" ||
        die "${base_tag} is not an ancestor of ${TARGET_BRANCH}"
fi

info ""
info "Bootstrap complete."
info ""
info "origin fetch policy:"
git config --get-all "remote.${ORIGIN_REMOTE}.fetch"
git config --get "remote.${ORIGIN_REMOTE}.tagOpt"

info ""
info "upstream fetch policy:"
git config --get-all "remote.${UPSTREAM_REMOTE}.fetch"
git config --get "remote.${UPSTREAM_REMOTE}.tagOpt"

if [[ -n "$TARGET_BRANCH" ]]; then
    info ""
    info "current branch:"
    git branch --show-current
    info "tracking:"
    git for-each-ref \
        --format='%(refname:short) -> %(upstream:short)' \
        "refs/heads/${TARGET_BRANCH}"
fi
