#!/bin/bash
#
# Installs VersionFrau for Xcode from GitHub.
#
#   curl -fsSL https://raw.githubusercontent.com/aralel/versionfrau-ios/main/install.sh | bash
#       installs the `versionfrau` command (/usr/local/bin if writable, else ~/.local/bin)
#
#   curl -fsSL https://raw.githubusercontent.com/aralel/versionfrau-ios/main/install.sh | bash -s -- MyApp.xcodeproj
#       sets up one project without installing the command (arguments are passed to `versionfrau install`)
#
# Environment:
#   VERSIONFRAU_REF           tag or branch to install (default: latest release, else main)
#   VERSIONFRAU_PREFIX        directory to install the command into
#   VERSIONFRAU_DOWNLOAD_URL  full URL of the script (overrides VERSIONFRAU_REF; file:// works)
#
# Copyright (c) Aralel GmbH — MIT License

set -euo pipefail

readonly repository="aralel/versionfrau-ios"

fail() { echo "error: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "VersionFrau for Xcode needs macOS"
command -v curl >/dev/null || fail "curl is required"

latest_release_tag() {
    curl -fsSL "https://api.github.com/repos/$repository/releases/latest" 2>/dev/null \
        | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

download_url="${VERSIONFRAU_DOWNLOAD_URL:-}"
if [ -z "$download_url" ]; then
    git_reference="${VERSIONFRAU_REF:-$(latest_release_tag)}"
    git_reference="${git_reference:-main}"
    download_url="https://raw.githubusercontent.com/$repository/$git_reference/bin/versionfrau"
fi

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
downloaded_script="$temporary_directory/versionfrau"
echo "Downloading $download_url"
curl -fsSL "$download_url" -o "$downloaded_script" || fail "download failed: $download_url"
head -n 1 "$downloaded_script" | grep -q '^#!/bin/bash' || fail "downloaded file is not the versionfrau script"
chmod +x "$downloaded_script"

if [ $# -gt 0 ]; then
    "$downloaded_script" install "$@"
    exit
fi

install_directory="${VERSIONFRAU_PREFIX:-}"
if [ -z "$install_directory" ]; then
    if [ -w /usr/local/bin ]; then install_directory=/usr/local/bin; else install_directory="$HOME/.local/bin"; fi
fi
mkdir -p "$install_directory"
mv -f "$downloaded_script" "$install_directory/versionfrau"
echo "Installed versionfrau $("$install_directory/versionfrau" --version) to $install_directory/versionfrau"

case ":$PATH:" in
    *":$install_directory:"*) ;;
    *) echo "Note: $install_directory is not on your PATH. Add it, e.g. echo 'export PATH=\"$install_directory:\$PATH\"' >> ~/.zshrc" ;;
esac
echo "Next: versionfrau install MyApp.xcodeproj"
