#!/usr/bin/env bash
set -uo pipefail

die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  echo "Usage: $0 <npm-package>"
  echo ""
  echo "Examples:"
  echo "  $0 @anthropic-ai/claude-code"
  echo "  $0 @google/gemini-cli"
  echo "  $0 typescript"
  echo ""
  echo "Environment variables:"
  echo "  VERSION_OVERRIDE  Pin to a specific version instead of latest"
  exit 1
}

[[ $# -lt 1 ]] && usage

PACKAGE="$1"
LABEL="${PACKAGE##*/}"
LOCKFILE_OUT="./${LABEL}-lock.json"

# Derive scope: @anthropic-ai/claude-code -> anthropic-ai, typescript -> ""
if [[ "$PACKAGE" == @* ]]; then
  SCOPE="${PACKAGE%%/*}"
  SCOPE="${SCOPE#@}"
else
  SCOPE=""
fi

# 1. Resolve version
if [[ -n "${VERSION_OVERRIDE:-}" ]]; then
  VERSION="$VERSION_OVERRIDE"
  echo "Using pinned version: ${VERSION}" >&2
else
  echo "Fetching latest version of ${PACKAGE}..." >&2
  VERSION=$(curl -fsSL "https://registry.npmjs.org/${PACKAGE}/latest" | jq -r '.version') \
    || die "Failed to fetch version for ${PACKAGE}"
  [[ -z "$VERSION" || "$VERSION" == "null" ]] && die "Could not resolve version for ${PACKAGE}"
  echo "Latest version: ${VERSION}" >&2
fi

# 2. Compute tarball hash
TARBALL_URL="https://registry.npmjs.org/${PACKAGE}/-/${LABEL}-${VERSION}.tgz"
echo "Computing tarball hash..." >&2
SHA256_RAW=$(nix-prefetch-url --unpack --type sha256 "$TARBALL_URL" 2>/dev/null) \
  || die "Failed to compute tarball hash for ${TARBALL_URL}"
SHA256=$(nix hash convert --hash-algo sha256 --to sri "$SHA256_RAW") \
  || die "Failed to convert hash to SRI format"
echo "Tarball hash: ${SHA256}" >&2

# 3. Unpack tarball and generate package-lock.json
echo "Generating package-lock.json..." >&2
TMPDIR=$(mktemp -d) || die "Failed to create temp directory"
trap "rm -rf $TMPDIR" EXIT

curl -fsSL "$TARBALL_URL" | tar xz -C "$TMPDIR" \
  || die "Failed to download and unpack tarball"
pushd "$TMPDIR/package" > /dev/null \
  || die "Failed to enter unpacked package directory"
npm install --package-lock-only --ignore-scripts 2>/dev/null \
  || die "npm install --package-lock-only failed"
popd > /dev/null

cp "$TMPDIR/package/package-lock.json" "$LOCKFILE_OUT" \
  || die "Failed to copy package-lock.json to ${LOCKFILE_OUT}"
echo "Written package-lock.json to ${LOCKFILE_OUT}" >&2

# 4. Compute npmDepsHash
echo "Computing npmDepsHash..." >&2
NPM_DEPS_HASH=$(prefetch-npm-deps "$LOCKFILE_OUT") \
  || die "Failed to compute npmDepsHash"
[[ -z "$NPM_DEPS_HASH" ]] && die "npmDepsHash is empty"
echo "npmDepsHash: ${NPM_DEPS_HASH}" >&2

# 5. Print derivation entry
SCOPE_ARG="${SCOPE:+\"${SCOPE}\" }"
LOCKFILE_NIX_PATH="./$(basename ${LOCKFILE_OUT})"

echo ""
echo "  ${LABEL} = npmjs ${SCOPE_ARG}\"${VERSION}\""
echo "    \"${SHA256}\""
echo "    \"${NPM_DEPS_HASH}\""
echo "    // { packageLockJson = ${LOCKFILE_NIX_PATH}; };"
