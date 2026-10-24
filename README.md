# VersionFrau for Xcode

Automatic version and build numbers for iOS, macOS, watchOS, tvOS and visionOS apps. The version lives in a small
`version.properties` file next to your `.xcodeproj`, and every build writes it into the app and all its extensions.

- **Debug build** (any configuration that isn't a release one) → increments **build**
- **Release build / Archive** (the `Release` configuration) → increments **patch** (resets build to 0)

It's a Swift package for Xcode: add it to your project, right-click the project, choose **Install VersionFrau**, and you're done.

## Installation (Swift Package)

1. In Xcode: **File → Add Package Dependencies…** and enter

   ```
   https://github.com/aralel/versionfrau-ios
   ```

   Pick **Up to Next Major Version** from `1.0.0`. Add the **VersionFrau** library to your app target if you want to
   read the version in Swift (optional).
2. In the Project navigator, **right-click your project → Install VersionFrau**. Allow it to change the project (and,
   the first time, to download the `xcodeproj` Ruby gem).
3. Build. `version.properties` appears next to your `.xcodeproj`; commit it, together with the copied `versionfrau` script.

The same context menu has **Bump Minor Version** and **Bump Major Version**. Build and patch are incremented by builds.

Builds don't depend on the package: they run the `versionfrau` script that was copied next to your project. Run
**Install VersionFrau** again after updating the package to update that copy.

## Installation (command line)

For CI, scripts, or if you'd rather not add a package dependency, the same tool is a single shell script.

**Homebrew**

```bash
brew tap aralel/versionfrau-ios https://github.com/aralel/versionfrau-ios
brew install versionfrau-xcode
```

**curl**

```bash
curl -fsSL https://raw.githubusercontent.com/aralel/versionfrau-ios/main/install.sh | bash
```

This installs the latest release to `/usr/local/bin`, or to `~/.local/bin` if `/usr/local/bin` isn't writable.
`VERSIONFRAU_REF=v1.0.0` pins a version, and `VERSIONFRAU_PREFIX=<dir>` picks the folder.

Then set up a project:

```bash
cd path/to/your/app
versionfrau install MyApp.xcodeproj
```

Or, without installing anything:

```bash
curl -fsSL https://raw.githubusercontent.com/aralel/versionfrau-ios/main/install.sh | bash -s -- MyApp.xcodeproj
```

## What Install does

Install (the Xcode plugin or `versionfrau install`) uses the [`xcodeproj`](https://github.com/CocoaPods/Xcodeproj) Ruby
gem. If your Ruby doesn't have it, it's downloaded once (the command line uses `~/.versionfrau/gems`, the plugin its own
work folder). No sudo is needed and your Ruby setup isn't changed. Builds themselves only need the copied shell script,
not Ruby.

Install:

1. Copies `versionfrau` next to `MyApp.xcodeproj`. Commit it, so builds never depend on a global install.
2. Adds a **Build pre-action** (`VersionFrau increment`) to every shared scheme. It increments the version once per build.
3. Adds a **Run Script phase** (`VersionFrau`, last phase) to every app and app-extension target. It writes the version into
   that target's built `Info.plist`, so the app and all its extensions always carry the same version.
4. Sets `ENABLE_USER_SCRIPT_SANDBOXING = NO` on those targets. The phase edits the built `Info.plist` and reads `version.properties`.

You can run it again at any time. It replaces its own phase and pre-action instead of adding duplicates.

Command-line options:

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

Add the **VersionFrau** library to your target:

```swift
import VersionFrau

Text("Version \(VersionFrau.versionName), built \(VersionFrau.buildTime)")
// also: VersionFrau.marketingVersion, .bundleVersion, .fullVersionName
// another bundle (e.g. from an extension): VersionFrau.Info(bundle: Bundle(for: SomeClass.self))
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

Point each project at the same file with the command-line installer (the Xcode plugin always uses
`version.properties` next to the project). Concurrent writes are locked, so parallel builds don't lose increments:

```bash
versionfrau install App/App.xcodeproj --file ../version.properties
versionfrau install MacApp/MacApp.xcodeproj --file ../version.properties
```

## Updating

Swift package: **File → Packages → Update to Latest Package Versions**, then right-click the project →
**Install VersionFrau** again to update the copied script. Command line: `brew upgrade versionfrau-xcode` or the curl
installer, then `versionfrau install MyApp.xcodeproj` again.

## Tests

```bash
tests/run-tests.sh          # unit tests, swift test, plugins, and builds a generated iOS app with a widget extension
tests/run-tests.sh --unit   # unit tests only
```

The integration tests need `xcodegen` (`brew install xcodegen`) and the `xcodeproj` gem. They also run on GitHub
Actions (`.github/workflows/tests.yml`).

## Releasing (maintainers)

```bash
scripts/release.sh 1.1.0             # sets the version in bin/versionfrau, adds the CHANGELOG heading, runs unit tests
git commit -am "Release v1.1.0" && git tag v1.1.0 && git push && git push --tags   # the tag is the Swift package version
# create the GitHub release for v1.1.0 (the curl installer installs the latest release)
scripts/release.sh --formula 1.1.0   # writes the tarball url + sha256 into Formula/versionfrau-xcode.rb
git commit -am "Formula v1.1.0" && git push
```

Xcode's "Up to Next Major Version" only finds tagged versions. Until `v1.0.0` is tagged, add the package with
**Dependency Rule: Branch → main**, and install the formula with `brew install --HEAD versionfrau-xcode`.

## License

MIT, Aralel GmbH
