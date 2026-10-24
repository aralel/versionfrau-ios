import Foundation
import PackagePlugin

/// Right-click the project in Xcode → Install VersionFrau. Same as `versionfrau install App.xcodeproj`.
@main
struct InstallVersionFrau: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        throw VersionFrauPluginError("Install VersionFrau sets up Xcode projects. In Xcode, right-click your project in the navigator and choose Install VersionFrau")
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension InstallVersionFrau: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let projectDirectory = context.xcodeProject.directoryURL
        let projectFile = try VersionFrauScript.xcodeProjectFile(in: projectDirectory, named: context.xcodeProject.displayName)
        // The plugin sandbox can only write to the project and its work directory, so a missing
        // xcodeproj gem is installed there instead of ~/.versionfrau/gems.
        let gemDirectory = context.pluginWorkDirectoryURL.appendingPathComponent("gems")
        try VersionFrauScript.run(
            ["install", projectFile.lastPathComponent],
            in: projectDirectory,
            environment: ["VERSIONFRAU_GEM_HOME": gemDirectory.path]
        )
    }
}
#endif
