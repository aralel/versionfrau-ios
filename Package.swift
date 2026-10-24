// swift-tools-version: 6.0
//
// VersionFrau for Xcode — add https://github.com/aralel/versionfrau-ios with
// File → Add Package Dependencies…, then right-click your project → "Install VersionFrau".

import PackageDescription

let package = Package(
    name: "VersionFrau",
    platforms: [.iOS(.v12), .macOS(.v10_13), .tvOS(.v12), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "VersionFrau", targets: ["VersionFrau"]),
        .plugin(name: "Install VersionFrau", targets: ["Install VersionFrau"]),
        .plugin(name: "Bump Minor Version", targets: ["Bump Minor Version"]),
        .plugin(name: "Bump Major Version", targets: ["Bump Major Version"]),
    ],
    targets: [
        .target(name: "VersionFrau"),
        .testTarget(name: "VersionFrauTests", dependencies: ["VersionFrau"], path: "tests/VersionFrauTests"),
        .plugin(
            name: "Install VersionFrau",
            capability: .command(
                intent: .custom(verb: "versionfrau-install", description: "Set up automatic version numbers for this Xcode project"),
                permissions: [
                    .writeToPackageDirectory(reason: "Adds the VersionFrau build phase and scheme pre-action, and copies the versionfrau script next to the project"),
                    .allowNetworkConnections(scope: .all(ports: [443]), reason: "Downloads the xcodeproj Ruby gem once if it isn't installed"),
                ]
            ),
            path: "Plugins/InstallVersionFrau"
        ),
        .plugin(
            name: "Bump Minor Version",
            capability: .command(
                intent: .custom(verb: "versionfrau-bump-minor", description: "Increment the minor version (resets patch and build)"),
                permissions: [.writeToPackageDirectory(reason: "Updates version.properties")]
            ),
            path: "Plugins/BumpMinorVersion"
        ),
        .plugin(
            name: "Bump Major Version",
            capability: .command(
                intent: .custom(verb: "versionfrau-bump-major", description: "Increment the major version (resets minor, patch and build)"),
                permissions: [.writeToPackageDirectory(reason: "Updates version.properties")]
            ),
            path: "Plugins/BumpMajorVersion"
        ),
    ]
)
