import Foundation
import PackagePlugin

/// Increments the major version and resets minor, patch and build. Same as `versionfrau bump major`.
@main
struct BumpMajorVersion: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try VersionFrauScript.run(["bump", "major"], in: context.package.directoryURL)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension BumpMajorVersion: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        try VersionFrauScript.run(["bump", "major"], in: context.xcodeProject.directoryURL)
    }
}
#endif
