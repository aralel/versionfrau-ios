import Foundation
import PackagePlugin

/// Increments the minor version and resets patch and build. Same as `versionfrau bump minor`.
@main
struct BumpMinorVersion: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try VersionFrauScript.run(["bump", "minor"], in: context.package.directoryURL)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension BumpMinorVersion: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        try VersionFrauScript.run(["bump", "minor"], in: context.xcodeProject.directoryURL)
    }
}
#endif
