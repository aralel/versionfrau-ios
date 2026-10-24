# Changelog

## [Unreleased]

### Swift Package
- The repository is now a Swift package (`Package.swift`, tools 6.0) that Xcode can add with **File → Add Package Dependencies…** from `https://github.com/aralel/versionfrau-ios`
- `VersionFrau` library: `VersionFrau.marketingVersion`, `.bundleVersion`, `.versionName`, `.fullVersionName`, `.buildTime`, and `VersionFrau.Info(bundle:)` for other bundles. iOS 12, macOS 10.13, tvOS 12, watchOS 9, visionOS 1
- Xcode command plugins (right-click the project): **Install VersionFrau** (runs `versionfrau install` on the open project, installs the xcodeproj gem into the plugin's work folder if missing), **Bump Minor Version**, **Bump Major Version**. The bump plugins also work with `swift package versionfrau-bump-minor|major`
- Tests: `swift test`, a dependent package that builds with the library and runs both bump plugins, and the Xcode integration sample app now imports the library through SwiftPM. 37 tests passing. The Xcode-only plugin code was type-checked against Xcode's `XcodeProjectPlugin` API
- Repository URLs changed from `aralel/versionfrau-xcode` to `aralel/versionfrau-ios` (README, install.sh, release.sh, formula)
- `.gitignore`: `.build/`, `.swiftpm/`, `Package.resolved`

### Changed
- Xcode first: removed all Android / Gradle framing from the script, README, formula and tests. The tool stands on its own and no longer advertises sharing a version file with an Android app
- `print versionCode` is now `print bundleVersion` (the `CFBundleVersion` value). `print` with no key lists `marketingVersion` and `bundleVersion` first
- `version.properties` gets a one-line header (`# VersionFrau - auto-managed version file, change it with 'versionfrau bump'`) instead of the Java-style comment and timestamp, so it no longer changes on every build except for the numbers
- README: "Sharing one version file with Android" replaced by "Several projects, one version" (`--file ../version.properties`)

### Packaging
- Moved out of the VersionFrau Gradle repo (`versionfrau/xcode/`) into its own repository, `aralel/versionfrau-xcode`. The script is now at `bin/versionfrau`
- Homebrew formula in the repo (`Formula/versionfrau-xcode.rb`). Install with `brew tap aralel/versionfrau-xcode https://github.com/aralel/versionfrau-xcode && brew install versionfrau-xcode`. Verified with a local tap: install plus `brew test`
- `install.sh` curl installer: installs the latest release (or `VERSIONFRAU_REF`) to `/usr/local/bin` or `~/.local/bin`, or with `bash -s -- MyApp.xcodeproj` sets up one project without installing anything
- `scripts/release.sh`: sets the version and CHANGELOG heading. With `--formula <version>`, writes the release tarball `url` and `sha256` into the formula
- GitHub Actions workflow running the unit and Xcode integration tests on macOS
- `versionfrau install` no longer needs a preinstalled `xcodeproj` gem. If it's missing, the gem is installed once into `~/.versionfrau/gems` (override with `VERSIONFRAU_GEM_HOME`), using the RubyGems of the same `ruby`. No sudo is needed. Verified with the stock macOS Ruby 2.6 on an empty home folder

### Added
- VersionFrau for Xcode: a dependency-free bash script that keeps the version in `version.properties`. Debug configurations increment `build`; `Release` (and Archive) increments `patch` and resets `build`. Configurable with `VERSIONFRAU_RELEASE_CONFIGURATIONS`
  - `increment` runs as a scheme Build pre-action, once per build. `apply` runs as the last Run Script phase of each app and extension target and writes `CFBundleShortVersionString` (three-part), `CFBundleVersion` (one number that grows with every build and release), `VersionFrauVersionName`, `VersionFrauFullVersionName` and `VersionFrauBuildTime` into the built `Info.plist`, so the app and its extensions always match. `run` combines both for single-target apps
  - `bump build|patch|minor|major` and `print [key]`. Index and clean builds don't increment. Concurrent writes are locked, so several targets or projects can share one file
  - `install <App.xcodeproj>` copies the script next to the project and adds the pre-action and Run Script phases. It disables user script sandboxing for those targets and is idempotent. Options: `--scheme`, `--target`, `--file`
- `tests/run-tests.sh`: 15 unit tests, plus 18 integration tests that generate an iOS app with a widget extension and build it with `xcodebuild` (Debug ×2, Release). Also verified `xcodebuild archive` (Xcode 27.1)
