#!/usr/bin/env bash
set -euo pipefail

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

print_bun_recovery() {
    local required="$1"
    local current="$2"
    local bun_path="$3"

    cat >&2 <<EOF

Required Bun : ${required}
Current Bun  : ${current}
Bun binary   : ${bun_path}

Build stopped before invoking upstream build tooling.

For this release migration, keep the existing ~/.bun/bin/bun unchanged.
Install the required Bun in a separate directory, and select that binary
using a command-scoped PATH. Check that 'bun --version' reports the required
version before installing dependencies in this isolated worktree.

Do not remove node_modules from another worktree or run a global Bun installer
as an automatic fix for this version mismatch. A deliberate future change to
the host default Bun requires separate review of other dependent projects.

If the active Bun is managed by another installer/package manager, identify
its owner and PATH precedence before making any host-level changes.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
cd "$repo_root"

[[ -f package.json ]] ||
    die "package.json not found at repository root"

package_manager=""
while IFS= read -r line; do
    if [[ "$line" =~ \"packageManager\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        package_manager="${BASH_REMATCH[1]}"
        break
    fi
done < package.json

[[ -n "$package_manager" ]] ||
    die "packageManager is not declared in package.json"

[[ "$package_manager" =~ ^bun@([0-9]+\.[0-9]+\.[0-9]+)$ ]] ||
    die "unsupported packageManager '${package_manager}'; review the target release build contract and adapt sky-tools/build-local.sh"

expected_bun="${BASH_REMATCH[1]}"

if ! command -v bun >/dev/null 2>&1; then
    print_bun_recovery "$expected_bun" "NOT FOUND" "NOT FOUND"
    die "Bun is not available in PATH"
fi

bun_path="$(command -v bun)"
actual_bun="$(bun --version)"

if [[ "$actual_bun" != "$expected_bun" ]]; then
    print_bun_recovery "$expected_bun" "$actual_bun" "$bun_path"
    die "Bun version mismatch"
fi

[[ -f bun.lock ]] ||
    die "bun.lock not found; review the current release dependency contract"

[[ -d node_modules ]] ||
    die "node_modules not found; run 'bun install --frozen-lockfile' before building"

[[ -x packages/opencode/script/build.ts ]] ||
    die "upstream build entry point is missing or not executable: packages/opencode/script/build.ts"

echo "OpenCode local build preflight"
echo "  package manager : ${package_manager}"
echo "  bun             : ${actual_bun}"
echo "  bun binary      : ${bun_path}"
echo "  lockfile        : bun.lock"
echo "  dependencies    : node_modules present"
echo "  build entry     : packages/opencode/script/build.ts --single"
echo

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
