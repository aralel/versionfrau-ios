# Changelog

## [Unreleased]

### Packaging
- Moved out of the VersionFrau Gradle repo (`versionfrau/xcode/`) into its own repository, `aralel/versionfrau-xcode`. The script is now at `bin/versionfrau`
- Homebrew formula in the repo (`Formula/versionfrau-xcode.rb`). Install with `brew tap aralel/versionfrau-xcode https://github.com/aralel/versionfrau-xcode && brew install versionfrau-xcode`. Verified with a local tap: install plus `brew test`
- `install.sh` curl installer: installs the latest release (or `VERSIONFRAU_REF`) to `/usr/local/bin` or `~/.local/bin`, or with `bash -s -- MyApp.xcodeproj` sets up one project without installing anything
- `scripts/release.sh`: sets the version and CHANGELOG heading. With `--formula <version>`, writes the release tarball `url` and `sha256` into the formula
- GitHub Actions workflow running the unit and Xcode integration tests on macOS
- `versionfrau install` no longer needs a preinstalled `xcodeproj` gem. If it's missing, the gem is installed once into `~/.versionfrau/gems` (override with `VERSIONFRAU_GEM_HOME`), using the RubyGems of the same `ruby`. No sudo is needed. Verified with the stock macOS Ruby 2.6 on an empty home folder

### Added
- VersionFrau for Xcode: a dependency-free bash script with the same `version.properties` format and the same rules as the Gradle plugin. Debug configurations increment `build`; `Release` (and Archive) increments `patch` and resets `build`. Configurable with `VERSIONFRAU_RELEASE_CONFIGURATIONS`
  - `increment` runs as a scheme Build pre-action, once per build. `apply` runs as the last Run Script phase of each app and extension target and writes `CFBundleShortVersionString` (three-part), `CFBundleVersion` (the Android `versionCode`), `VersionFrauVersionName`, `VersionFrauFullVersionName` and `VersionFrauBuildTime` into the built `Info.plist`, so the app and its extensions always match. `run` combines both for single-target apps
  - `bump build|patch|minor|major` and `print [key]` work like the Gradle tasks. Index and clean builds don't increment. Concurrent writes are locked, so Xcode and Gradle can share one file
  - `install <App.xcodeproj>` copies the script next to the project and adds the pre-action and Run Script phases. It disables user script sandboxing for those targets and is idempotent. Options: `--scheme`, `--target`, `--file`
- `tests/run-tests.sh`: 15 unit tests, plus 18 integration tests that generate an iOS app with a widget extension and build it with `xcodebuild` (Debug ×2, Release). Also verified `xcodebuild archive` (Xcode 27.1)
