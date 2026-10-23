# VersionFrau for Xcode

Automatic version and build numbers for iOS, macOS, watchOS, tvOS and visionOS apps. The version lives in a small
`version.properties` file next to your `.xcodeproj`, and every build writes it into the app and all its extensions.

- **Debug build** (any configuration that isn't a release one) → increments **build**
- **Release build / Archive** (the `Release` configuration) → increments **patch** (resets build to 0)

It's a single dependency-free shell script that lives in your repo next to the `.xcodeproj`.

## Installation

**Homebrew**

```bash
brew tap aralel/versionfrau-xcode https://github.com/aralel/versionfrau-xcode
brew install versionfrau-xcode
```

**curl**

```bash
curl -fsSL https://raw.githubusercontent.com/aralel/versionfrau-xcode/main/install.sh | bash
```

This installs the latest release to `/usr/local/bin`, or to `~/.local/bin` if `/usr/local/bin` isn't writable.
`VERSIONFRAU_REF=v1.0.0` pins a version, and `VERSIONFRAU_PREFIX=<dir>` picks the folder.

**Without installing anything:** set up one project straight from GitHub.

```bash
curl -fsSL https://raw.githubusercontent.com/aralel/versionfrau-xcode/main/install.sh | bash -s -- MyApp.xcodeproj
```

## Setup

```bash
cd path/to/your/app
versionfrau install MyApp.xcodeproj
```

The installer needs the [`xcodeproj`](https://github.com/CocoaPods/Xcodeproj) Ruby gem. If your Ruby doesn't have it, the
installer downloads it once into `~/.versionfrau/gems`. No sudo is needed and your Ruby setup isn't changed.
Builds themselves only need the copied shell script, not Ruby.

The installer:

1. Copies `versionfrau` next to `MyApp.xcodeproj`. Commit it, so builds never depend on a global install.
2. Adds a **Build pre-action** (`VersionFrau increment`) to every shared scheme. It increments the version once per build.
3. Adds a **Run Script phase** (`VersionFrau`, last phase) to every app and app-extension target. It writes the version into
   that target's built `Info.plist`, so the app and all its extensions always carry the same version.
4. Sets `ENABLE_USER_SCRIPT_SANDBOXING = NO` on those targets. The phase edits the built `Info.plist` and reads `version.properties`.

You can run it again at any time. It replaces its own phase and pre-action instead of adding duplicates.

| Option | Description |
|---|---|
| `--scheme <name>` | Only add the pre-action to this shared scheme (default: all shared schemes, or create one) |
| `--target <name>` | Only these targets (repeatable; default: all app and app-extension targets) |
| `--file <path>` | Version file relative to the project dir, e.g. `../version.properties` for a file shared by several projects |

### Manual setup

If you don't want the gem, set it up by hand:

1. Copy `versionfrau` next to your `.xcodeproj` and `chmod +x` it.
2. **Scheme → Edit Scheme → Build → Pre-actions → + New Run Script Action**
   - *Provide build settings from*: your app target
   - Script: `"${PROJECT_DIR}/versionfrau" increment`
3. For each app and extension target: **Build Phases → + New Run Script Phase** (move it to the end)
   - Script: `"${PROJECT_DIR}/versionfrau" apply`
   - Input Files: `$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)`
   - Uncheck *Based on dependency analysis*
4. Build Settings → **User Script Sandboxing** → `No` for those targets.

**Single-target apps** can skip the pre-action. Use one Run Script phase with
`"${PROJECT_DIR}/versionfrau" run`, which increments and applies in one step. Don't use `run` when
you have extensions: each target would increment separately.

## How It Works

`version.properties` (created on the first build if missing):

```properties
major=1
minor=0
patch=0
build=0
```

| Build | What happens | Built `Info.plist` |
|---|---|---|
| ⌘B / ⌘R (Debug) | `build` incremented | `1.0.3` (`1000003042`) |
| Archive / Release build | `patch` incremented, `build` reset to 0 | `1.0.4` (`1000004000`) |
| Indexing, Clean | nothing | n/a |

Keys written into every target's built `Info.plist`:

| Key | Debug example | Release example | Description |
|---|---|---|---|
| `CFBundleShortVersionString` | `1.0.3` | `1.0.4` | Always three-part (App Store Connect allows at most three integers) |
| `CFBundleVersion` | `1000003042` | `1000004000` | Bundle version: one number that grows with every build and release |
| `VersionFrauVersionName` | `1.0.3.42` | `1.0.4` | Display version (includes build only on debug) |
| `VersionFrauFullVersionName` | `1.0.3.42` | `1.0.4.0` | Always includes build |
| `VersionFrauBuildTime` | `Oct 24, 2026` | `Oct 24, 2026` | Build date |

The bundle version is `major * 1_000_000_000 + minor * 1_000_000 + patch * 1_000 (+ build on debug)`.
It grows with every build and release, as App Store Connect requires.

`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in your build settings are overridden in the
built product, so you can leave them as they are. Your source `Info.plist` is never modified.

### Reading the values in Swift

```swift
enum BuildConfig {
    private static func value(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
    static let versionName = value("VersionFrauVersionName")
    static let fullVersionName = value("VersionFrauFullVersionName")
    static let buildTime = value("VersionFrauBuildTime")
}
```

### Configurations

`Release` is the only release configuration by default; every other one (`Debug`, `Staging`, …)
counts as debug. To change that, set the variable in the pre-action and the Run Script phase:

```bash
VERSIONFRAU_RELEASE_CONFIGURATIONS="Release AppStore" "${PROJECT_DIR}/versionfrau" increment
```

## Commands

```bash
./versionfrau print                     # all values
./versionfrau print bundleVersion       # one value (marketingVersion, versionName, fullVersionName, buildTime, …)
./versionfrau bump build|patch|minor|major
```

`bump minor` resets patch and build, and `bump major` resets minor, patch and build. These commands also work in CI, e.g. `./versionfrau print marketingVersion` for release notes.

## Several projects, one version

Point each project at the same file. Concurrent writes are locked, so parallel builds don't lose increments:

```bash
versionfrau install App/App.xcodeproj --file ../version.properties
versionfrau install MacApp/MacApp.xcodeproj --file ../version.properties
```

## Updating

`brew upgrade versionfrau-xcode`, or run the curl installer again. Then run `versionfrau install MyApp.xcodeproj`
again to update the copy of the script in your project.

## Tests

```bash
tests/run-tests.sh          # unit tests + builds a generated iOS app with a widget extension
tests/run-tests.sh --unit   # unit tests only
```

The integration tests need `xcodegen` (`brew install xcodegen`) and the `xcodeproj` gem. They also run on GitHub
Actions (`.github/workflows/tests.yml`).

## Releasing (maintainers)

```bash
scripts/release.sh 1.1.0             # sets the version in bin/versionfrau, adds the CHANGELOG heading, runs unit tests
git commit -am "Release v1.1.0" && git tag v1.1.0 && git push && git push --tags
# create the GitHub release for v1.1.0 (the curl installer installs the latest release)
scripts/release.sh --formula 1.1.0   # writes the tarball url + sha256 into Formula/versionfrau-xcode.rb
git commit -am "Formula v1.1.0" && git push
```

Until the first release, the formula has no stable version: install it with `brew install --HEAD versionfrau-xcode`.

## License

MIT, Aralel GmbH
