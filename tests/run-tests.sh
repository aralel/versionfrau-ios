#!/bin/bash
#
# Tests for the VersionFrau Xcode script.
#
#   tests/run-tests.sh            unit + Swift package + Xcode integration tests
#   tests/run-tests.sh --unit     unit tests only (no Xcode needed)
#
# The integration tests generate an iOS app with an embedded widget extension (xcodegen) that uses
# the VersionFrau Swift package, install VersionFrau with `versionfrau install` (xcodeproj gem) and
# build it with xcodebuild.

set -uo pipefail

readonly package_directory="$(cd "$(dirname "$0")/.." && pwd)"
readonly versionfrau_script="$package_directory/bin/versionfrau"
work_directory="$(mktemp -d "${TMPDIR:-/tmp}/versionfrau-tests.XXXXXX")"
[ -n "${VERSIONFRAU_KEEP_TEST_DIR:-}" ] && echo "Test directory: $work_directory" || trap 'rm -rf "$work_directory"' EXIT

passed_count=0
failed_count=0

assert_equals() {
    local description="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        passed_count=$((passed_count + 1))
        echo "  ✓ $description"
    else
        failed_count=$((failed_count + 1))
        echo "  ✗ $description — expected '$expected', got '$actual'"
    fi
}

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }

# A build setting as Xcode resolves it (what the target's General tab shows).
build_setting() {
    local configuration="$1" setting="$2"
    xcodebuild -project "$project_directory/Sample.xcodeproj" -target Sample -configuration "$configuration" \
        -showBuildSettings 2>/dev/null | sed -n "s/^ *$setting = //p"
}

# --- unit tests -------------------------------------------------------------------------------

run_unit_tests() {
    echo "Unit tests"
    local unit_directory="$work_directory/unit"
    mkdir -p "$unit_directory"
    cd "$unit_directory" || exit 1

    "$versionfrau_script" print >/dev/null
    assert_equals "creates version.properties with 1.0.0.0" "1.0.0.0" "$("$versionfrau_script" print fullVersionName)"

    CONFIGURATION=Debug "$versionfrau_script" increment >/dev/null
    CONFIGURATION=Debug "$versionfrau_script" increment >/dev/null
    assert_equals "debug increment bumps build" "1.0.0.2" "$(CONFIGURATION=Debug "$versionfrau_script" print versionName)"
    assert_equals "debug bundleVersion includes build" "1000000002" "$(CONFIGURATION=Debug "$versionfrau_script" print bundleVersion)"

    CONFIGURATION=Release "$versionfrau_script" increment >/dev/null
    assert_equals "release increment bumps patch, resets build" "1.0.1.0" "$("$versionfrau_script" print fullVersionName)"
    assert_equals "release versionName is three-part" "1.0.1" "$(CONFIGURATION=Release "$versionfrau_script" print versionName)"
    assert_equals "release bundleVersion excludes build" "1000001000" "$(CONFIGURATION=Release "$versionfrau_script" print bundleVersion)"

    VERSIONFRAU_RELEASE_CONFIGURATIONS="AppStore Release" CONFIGURATION=AppStore "$versionfrau_script" increment >/dev/null
    assert_equals "custom release configuration bumps patch" "1.0.2.0" "$("$versionfrau_script" print fullVersionName)"

    CONFIGURATION=Staging "$versionfrau_script" increment >/dev/null
    assert_equals "unknown configuration counts as debug" "1.0.2.1" "$("$versionfrau_script" print fullVersionName)"

    ACTION=indexbuild CONFIGURATION=Debug "$versionfrau_script" increment >/dev/null
    assert_equals "index builds do not increment" "1" "$("$versionfrau_script" print build)"

    "$versionfrau_script" bump minor >/dev/null
    assert_equals "bump minor resets patch and build" "1.1.0.0" "$("$versionfrau_script" print fullVersionName)"
    "$versionfrau_script" bump major >/dev/null
    assert_equals "bump major resets minor, patch and build" "2.0.0.0" "$("$versionfrau_script" print fullVersionName)"

    # A hand-edited file: comments, spaces around '=' and any key order.
    printf '# my app\nbuild = 41\npatch=3\nminor=0\nmajor=1\n' > version.properties
    CONFIGURATION=Debug "$versionfrau_script" increment >/dev/null
    assert_equals "reads hand-edited version.properties" "1.0.3.42" "$("$versionfrau_script" print fullVersionName)"

    CONFIGURATION=Debug "$versionfrau_script" increment >/dev/null
    assert_equals "xcconfig MARKETING_VERSION" "1.0.3" "$(sed -n 's/^MARKETING_VERSION = //p' VersionFrau.xcconfig)"
    assert_equals "xcconfig CURRENT_PROJECT_VERSION (debug)" "1000003043" "$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' VersionFrau.xcconfig)"
    assert_equals "xcconfig CURRENT_PROJECT_VERSION (release)" "1000003000" "$(sed -n 's/^CURRENT_PROJECT_VERSION\[config=Release\] = //p' VersionFrau.xcconfig)"
    rm VersionFrau.xcconfig
    "$versionfrau_script" print >/dev/null
    assert_equals "missing xcconfig is recreated" "yes" "$([ -f VersionFrau.xcconfig ] && echo yes || echo no)"

    VERSIONFRAU_FILE="$unit_directory/config/version.properties" "$versionfrau_script" print >/dev/null
    assert_equals "VERSIONFRAU_FILE sets a custom location" "yes" "$([ -f config/version.properties ] && echo yes || echo no)"

    local parallel_index
    for parallel_index in 1 2 3 4 5 6 7 8; do
        CONFIGURATION=Debug "$versionfrau_script" increment >/dev/null &
    done
    wait
    assert_equals "parallel increments are not lost" "51" "$("$versionfrau_script" print build)"

    if ( unset TARGET_BUILD_DIR INFOPLIST_PATH; "$versionfrau_script" apply ) >/dev/null 2>&1; then
        assert_equals "apply outside Xcode fails" "failure" "success"
    else
        assert_equals "apply outside Xcode fails" "failure" "failure"
    fi
}

# --- Swift package tests ----------------------------------------------------------------------

run_package_tests() {
    echo "Swift package tests"
    if ! command -v swift >/dev/null; then
        echo "  skipped — needs swift"
        return
    fi
    (cd "$package_directory" && swift test) > "$work_directory/swift-test.log" 2>&1
    assert_equals "swift test passes (VersionFrau library)" "0" "$?"

    # A package that depends on VersionFrau, like an app does, and runs its command plugins.
    local consumer_directory="$work_directory/Consumer"
    mkdir -p "$consumer_directory/Sources/Consumer"
    cat > "$consumer_directory/Package.swift" <<SWIFT
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Consumer",
    dependencies: [.package(path: "$package_directory")],
    targets: [.target(name: "Consumer", dependencies: [.product(name: "VersionFrau", package: "$(basename "$package_directory")")])]
)
SWIFT
    echo 'import VersionFrau
public let shownVersion = VersionFrau.versionName' > "$consumer_directory/Sources/Consumer/Consumer.swift"
    (cd "$consumer_directory" && swift build) > "$work_directory/consumer-build.log" 2>&1
    assert_equals "a dependent package builds with the library" "0" "$?"
    (cd "$consumer_directory" && swift package --allow-writing-to-package-directory versionfrau-bump-minor) >/dev/null 2>&1
    assert_equals "Bump Minor Version plugin" "1.1.0.0" "$(cd "$consumer_directory" && "$versionfrau_script" print fullVersionName)"
    (cd "$consumer_directory" && swift package --allow-writing-to-package-directory versionfrau-bump-major) >/dev/null 2>&1
    assert_equals "Bump Major Version plugin" "2.0.0.0" "$(cd "$consumer_directory" && "$versionfrau_script" print fullVersionName)"
}

# --- Xcode integration tests ------------------------------------------------------------------

xcode_build() {
    local configuration="$1"
    xcodebuild -project "$project_directory/Sample.xcodeproj" -scheme Sample -configuration "$configuration" \
        -sdk iphonesimulator -derivedDataPath "$project_directory/DerivedData" \
        CODE_SIGNING_ALLOWED=NO build > "$project_directory/build-$configuration.log" 2>&1 \
        || { echo "  xcodebuild failed, log: $project_directory/build-$configuration.log"; tail -30 "$project_directory/build-$configuration.log"; return 1; }
}

run_integration_tests() {
    echo "Xcode integration tests"
    if ! command -v xcodebuild >/dev/null || ! command -v xcodegen >/dev/null || ! ruby -e 'require "xcodeproj"' 2>/dev/null; then
        echo "  skipped — needs xcodebuild, xcodegen and the xcodeproj gem"
        return
    fi

    project_directory="$work_directory/Sample"
    mkdir -p "$project_directory/App" "$project_directory/Widget"
    cat > "$project_directory/App/App.swift" <<'SWIFT'
import SwiftUI
import VersionFrau

@main
struct SampleApp: App {
    var body: some Scene {
        WindowGroup {
            Text("\(VersionFrau.versionName) — \(VersionFrau.buildTime)")
        }
    }
}
SWIFT
    cat > "$project_directory/Widget/Widget.swift" <<'SWIFT'
import WidgetKit
import SwiftUI

struct Entry: TimelineEntry { let date: Date }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

@main
struct SampleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SampleWidget", provider: Provider()) { _ in Text("Sample") }
    }
}
SWIFT
    cat > "$project_directory/project.yml" <<YAML
name: Sample
packages:
  VersionFrau:
    path: $package_directory
options:
  bundleIdPrefix: com.example
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    MARKETING_VERSION: "9.9.9"
    CURRENT_PROJECT_VERSION: "999"
    ENABLE_USER_SCRIPT_SANDBOXING: "YES"
targets:
  Sample:
    type: application
    platform: iOS
    sources: [App]
    info:
      path: App/Info.plist
      properties:
        CFBundleShortVersionString: \$(MARKETING_VERSION)
        CFBundleVersion: \$(CURRENT_PROJECT_VERSION)
        UILaunchScreen: {}
    dependencies:
      - target: SampleWidget
      - package: VersionFrau
  SampleWidget:
    type: app-extension
    platform: iOS
    sources: [Widget]
    info:
      path: Widget/Info.plist
      properties:
        CFBundleShortVersionString: \$(MARKETING_VERSION)
        CFBundleVersion: \$(CURRENT_PROJECT_VERSION)
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
schemes:
  Sample:
    build:
      targets:
        Sample: all
YAML
    (cd "$project_directory" && xcodegen generate --quiet) || { failed_count=$((failed_count + 1)); echo "  ✗ xcodegen failed"; return; }

    (cd "$project_directory" && "$versionfrau_script" install Sample.xcodeproj) > "$project_directory/install.log" 2>&1
    assert_equals "install succeeds" "0" "$?"
    assert_equals "install copies the script next to the project" "yes" "$([ -x "$project_directory/versionfrau" ] && echo yes || echo no)"
    (cd "$project_directory" && "$project_directory/versionfrau" install Sample.xcodeproj) >/dev/null 2>&1
    assert_equals "install is idempotent (one phase per target)" "2" \
        "$(grep -c 'name = VersionFrau;' "$project_directory/Sample.xcodeproj/project.pbxproj")"
    assert_equals "install is idempotent (one pre-action)" "1" \
        "$(grep -c 'title = "VersionFrau increment"' "$project_directory/Sample.xcodeproj/xcshareddata/xcschemes/Sample.xcscheme")"
    assert_equals "install is idempotent (one xcconfig reference)" "1" \
        "$(grep -c 'path = VersionFrau.xcconfig;' "$project_directory/Sample.xcodeproj/project.pbxproj")"
    assert_equals "install removes hard-coded MARKETING_VERSION" "0" \
        "$(grep -c 'MARKETING_VERSION' "$project_directory/Sample.xcodeproj/project.pbxproj")"
    assert_equals "Xcode Version comes from VersionFrau" "1.0.0" "$(build_setting Debug MARKETING_VERSION)"
    assert_equals "Xcode Build comes from VersionFrau" "1000000000" "$(build_setting Debug CURRENT_PROJECT_VERSION)"

    local app_plist="$project_directory/DerivedData/Build/Products/Debug-iphonesimulator/Sample.app/Info.plist"
    local widget_plist="$project_directory/DerivedData/Build/Products/Debug-iphonesimulator/Sample.app/PlugIns/SampleWidget.appex/Info.plist"

    xcode_build Debug || { failed_count=$((failed_count + 1)); return; }
    assert_equals "debug build increments build once (app + extension)" "1.0.0.1" "$(cd "$project_directory" && ./versionfrau print fullVersionName)"
    assert_equals "app CFBundleShortVersionString" "1.0.0" "$(plist_value "$app_plist" CFBundleShortVersionString)"
    assert_equals "app CFBundleVersion is the debug bundle version" "1000000001" "$(plist_value "$app_plist" CFBundleVersion)"
    assert_equals "app VersionFrauVersionName is four-part" "1.0.0.1" "$(plist_value "$app_plist" VersionFrauVersionName)"
    assert_equals "app VersionFrauBuildTime is set" "$(LC_ALL=en_US.UTF-8 date '+%b %d, %Y')" "$(plist_value "$app_plist" VersionFrauBuildTime)"
    assert_equals "extension CFBundleVersion matches the app" "1000000001" "$(plist_value "$widget_plist" CFBundleVersion)"
    assert_equals "extension CFBundleShortVersionString matches the app" "1.0.0" "$(plist_value "$widget_plist" CFBundleShortVersionString)"

    xcode_build Debug || { failed_count=$((failed_count + 1)); return; }
    assert_equals "incremental debug build increments again" "1000000002" "$(plist_value "$app_plist" CFBundleVersion)"
    assert_equals "incremental build updates the extension too" "1000000002" "$(plist_value "$widget_plist" CFBundleVersion)"
    assert_equals "Xcode Build follows debug builds" "1000000002" "$(build_setting Debug CURRENT_PROJECT_VERSION)"

    local release_app_plist="$project_directory/DerivedData/Build/Products/Release-iphonesimulator/Sample.app/Info.plist"
    local release_widget_plist="$project_directory/DerivedData/Build/Products/Release-iphonesimulator/Sample.app/PlugIns/SampleWidget.appex/Info.plist"
    xcode_build Release || { failed_count=$((failed_count + 1)); return; }
    assert_equals "release build increments patch, resets build" "1.0.1.0" "$(cd "$project_directory" && ./versionfrau print fullVersionName)"
    assert_equals "release CFBundleShortVersionString" "1.0.1" "$(plist_value "$release_app_plist" CFBundleShortVersionString)"
    assert_equals "release CFBundleVersion is the release bundle version" "1000001000" "$(plist_value "$release_app_plist" CFBundleVersion)"
    assert_equals "release VersionFrauVersionName is three-part" "1.0.1" "$(plist_value "$release_app_plist" VersionFrauVersionName)"
    assert_equals "release extension matches the app" "1000001000" "$(plist_value "$release_widget_plist" CFBundleVersion)"
    assert_equals "Xcode Version follows release builds" "1.0.1" "$(build_setting Release MARKETING_VERSION)"
    assert_equals "Xcode Build for Release" "1000001000" "$(build_setting Release CURRENT_PROJECT_VERSION)"
}

if [ "${1:-}" != "--integration" ]; then run_unit_tests; fi
if [ "${1:-}" != "--unit" ]; then run_package_tests; run_integration_tests; fi

echo
echo "$passed_count passed, $failed_count failed"
[ "$failed_count" -eq 0 ]
