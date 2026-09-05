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

For this WSL/Linux setup, if Bun is installed by the official Bun installer
under ~/.bun/bin, switch cleanly to the exact release-required version:

  curl -fsSL https://bun.com/install |
      bash -s "bun-v${required}"

  hash -r

  command -v bun
  type -a bun
  bun --version
  bun --revision

  rm -rf node_modules
  bun install --frozen-lockfile

  ./sky-tools/build-local.sh

The same exact-version installer command is valid for both upgrade and
downgrade.

Do not use 'bun upgrade' here: the build contract requires the exact version
declared by this checkout's package.json.

If 'command -v bun' does not point to ~/.bun/bin/bun, or 'type -a bun' shows
multiple Bun installations, do not mix installation methods. First identify
which installation currently wins PATH resolution and which installer/package
manager owns it. Use that same method for the exact version, or deliberately
remove the conflicting installation before switching to the official Bun
installer.
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

[[ -f packages/opencode/script/schema.ts ]] ||
    die "upstream config schema generator is missing: packages/opencode/script/schema.ts"

echo "OpenCode local build preflight"
echo "  package manager : ${package_manager}"
echo "  bun             : ${actual_bun}"
echo "  bun binary      : ${bun_path}"
echo "  lockfile        : bun.lock"
echo "  dependencies    : node_modules present"
echo "  build entry     : packages/opencode/script/build.ts --single"
echo "  schema entry    : packages/opencode/script/schema.ts"
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

schema_output="packages/opencode/dist/opencode.schema.json"

echo
echo "OpenCode local config schema"
echo "  source  : packages/opencode/script/schema.ts"
echo "  output  : ${schema_output}"
echo

(
    cd packages/opencode
    bun run script/schema.ts "${repo_root}/${schema_output}"
)

[[ -s "$schema_output" ]] ||
    die "generated config schema is missing or empty: ${schema_output}"

echo "Schema generated: ${schema_output}"
