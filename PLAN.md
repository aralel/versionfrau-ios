# Plan

## Current prompt (2026-10-24, Swift package)

> Xcode failed adding https://github.com/aralel/versionfrau-ios: "no versions of 'versionfrau-ios' match the requirement 1.0.0..<2.0.0"

### Status: done (no commits, no tags, not pushed)

- Cause: the repo had no `Package.swift` and no `1.0.0` tag.
- Added the Swift package: `VersionFrau` library + command plugins Install VersionFrau / Bump Minor Version /
  Bump Major Version. The plugins run `bin/versionfrau` from the package checkout (found via `#filePath`);
  shared helper `Plugins/Shared/VersionFrauScript.swift` is symlinked into each plugin directory.
- Why command plugins and not a build tool plugin: build tool plugins are sandboxed to their work directory, so they
  can neither persist the incremented version nor edit the built Info.plist.
- Plugin sandbox: Install gets `writeToPackageDirectory` + network (443) for the one-time gem download into the
  plugin work directory (`VERSIONFRAU_GEM_HOME`).
- Verified: 37 tests; plugins type-check against XcodeProjectPlugin. Not verified: running the plugins from the Xcode UI.
- To publish: commit, `git tag v1.0.0`, push with tags (or add the package with Branch: main until then).

## Current prompt (2026-10-24, Xcode first)

> forget the android app, we want an xcode first package

### Status: done (no commits)

- Removed Android/Gradle wording from `bin/versionfrau`, README, formula `desc`/test and the unit tests.
- Renamed `print versionCode` → `print bundleVersion` (unreleased, so no alias kept).
- The version file header no longer has a timestamp, so diffs only show the numbers.
- Kept the `version.properties` name and key=value format: simple, readable, and already tested.
- Verified: 33 tests passing (unit + Xcode integration).

## Previous prompt (2026-10-24, follow-up)

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
