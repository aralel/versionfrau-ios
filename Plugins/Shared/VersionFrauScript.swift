import Foundation
import PackagePlugin

/// Runs `bin/versionfrau` from this package's checkout. The plugins are thin wrappers around it,
/// so the build phase and the plugins always behave the same.
enum VersionFrauScript {
    /// Plugins/<Plugin>/VersionFrauScript.swift → <package root>/bin/versionfrau
    static var scriptURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("bin/versionfrau")
    }

    static func run(_ arguments: [String], in directory: URL, environment additionalEnvironment: [String: String] = [:]) throws {
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw VersionFrauPluginError("versionfrau script not found at \(scriptURL.path)")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path] + arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = [environment["PATH"], "/usr/bin:/bin:/usr/sbin:/sbin"].compactMap { $0 }.joined(separator: ":")
        environment.merge(additionalEnvironment) { _, additionalValue in additionalValue }
        process.environment = environment
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw VersionFrauPluginError("versionfrau \(arguments.joined(separator: " ")) failed with exit code \(process.terminationStatus)")
        }
    }

    /// The `.xcodeproj` in `directory`, preferring the one named like the open project.
    static func xcodeProjectFile(in directory: URL, named projectName: String) throws -> URL {
        let projectFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xcodeproj" }
        if let namedProjectFile = projectFiles.first(where: { $0.deletingPathExtension().lastPathComponent == projectName }) {
            return namedProjectFile
        }
        guard projectFiles.count == 1, let projectFile = projectFiles.first else {
            throw VersionFrauPluginError("expected one .xcodeproj in \(directory.path), found \(projectFiles.count)")
        }
        return projectFile
    }
}

struct VersionFrauPluginError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = "VersionFrau: \(description)" }
}
