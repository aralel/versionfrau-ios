# Plan

## Current prompt (2026-10-24, follow-up)

> can you move it out to it's own folder and also make it like a package we can install from github?

### Status: done (not pushed, no commits)

- Moved `versionfrau/xcode/` to `/Users/maysam/Workspace/aralel/versionfrau-xcode`, laid out as a package:
  `bin/versionfrau`, `Formula/versionfrau-xcode.rb`, `install.sh`, `scripts/release.sh`, `tests/`, `.github/workflows/tests.yml`, `LICENSE`.
- Assumed GitHub repo: `aralel/versionfrau-xcode`, used in the formula, install.sh and release.sh.
- The formula is installed from the repo itself as a custom-URL tap. A separate `aralel/homebrew-tap` would allow
  `brew install aralel/tap/versionfrau-xcode` without the URL.
- `install` auto-installs the xcodeproj gem into `~/.versionfrau/gems` when it's missing (stock macOS Ruby 2.6 works).
- Verified: 33 tests passing; the formula installs and passes `brew test` from a temporary local tap (removed again);
  install.sh tested with `VERSIONFRAU_DOWNLOAD_URL=file://…` in both modes.
- To publish: create the GitHub repo, push, tag v1.0.0, create the release, run `scripts/release.sh --formula 1.0.0`, push.

## Previous prompt (2026-10-24)

> can we make a similar plugin for xcode projects?

### Status: done

- `versionfrau` (bash 3.2, no dependencies): the scheme pre-action `increment` runs once per build, and the Run Script phase
  `apply` runs in each app and extension target and patches the built Info.plist. Uses the same version.properties format,
  formulas and debug/release rules as the Gradle plugin.
- Why a pre-action: extensions build before the app, so incrementing inside a target's phase would give the app and its
  extensions different CFBundleVersions, which App Store Connect rejects.
- Xcode 27 shows pre-action output and fails the build on a pre-action error.

## Backlog

- Optional `.ipa` renaming on `-exportArchive` (the analogue of the APK/AAB naming).
- SwiftUI preview builds are not detected and still increment.
