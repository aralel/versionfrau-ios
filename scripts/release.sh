#!/bin/bash
#
# Release helper (maintainers).
#
#   scripts/release.sh 1.1.0            sets the version in bin/versionfrau and adds a CHANGELOG heading
#   (commit, then: git tag v1.1.0 && git push && git push --tags, and create the GitHub release)
#   scripts/release.sh --formula 1.1.0  writes url + sha256 of the pushed v1.1.0 tarball into the Homebrew formula
#
# Copyright (c) Aralel GmbH — MIT License

set -euo pipefail

readonly repository="aralel/versionfrau-ios"
readonly project_directory="$(cd "$(dirname "$0")/.." && pwd)"
readonly formula_file="$project_directory/Formula/versionfrau-xcode.rb"

fail() { echo "error: $*" >&2; exit 1; }

update_formula() {
    local release_version="$1"
    local tarball_url="https://github.com/$repository/archive/refs/tags/v$release_version.tar.gz"
    local tarball_sha256
    tarball_sha256="$(curl -fsSL "$tarball_url" | shasum -a 256 | cut -d ' ' -f 1)" \
        || fail "could not download $tarball_url — is the tag pushed?"
    [ "$tarball_sha256" != "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ] \
        || fail "downloaded an empty file from $tarball_url"

    # Drop any previous url/sha256 lines, then insert the new ones after `homepage`.
    sed -i '' -e '/^  url "/d' -e '/^  sha256 "/d' "$formula_file"
    sed -i '' -e "/^  homepage \"/a\\
  url \"$tarball_url\"\\
  sha256 \"$tarball_sha256\"
" "$formula_file"
    echo "Formula updated: v$release_version ($tarball_sha256). Commit and push Formula/versionfrau-xcode.rb."
}

prepare_release() {
    local release_version="$1"
    sed -i '' "s/^readonly VERSIONFRAU_VERSION=\".*\"/readonly VERSIONFRAU_VERSION=\"$release_version\"/" "$project_directory/bin/versionfrau"
    if ! grep -q "^## \[$release_version\]" "$project_directory/CHANGELOG.md"; then
        sed -i '' "s/^## \[Unreleased\]/## [Unreleased]\\
\\
## [$release_version] - $(date +%Y-%m-%d)/" "$project_directory/CHANGELOG.md"
    fi
    "$project_directory/tests/run-tests.sh" --unit >/dev/null || fail "unit tests failed"
    echo "Prepared v$release_version. Next:"
    echo "  git commit -am \"Release v$release_version\" && git tag v$release_version && git push && git push --tags"
    echo "  scripts/release.sh --formula $release_version"
}

case "${1:-}" in
    --formula) [ -n "${2:-}" ] || fail "usage: scripts/release.sh --formula <version>"; update_formula "$2" ;;
    [0-9]*) prepare_release "$1" ;;
    *) fail "usage: scripts/release.sh <version> | --formula <version>" ;;
esac
