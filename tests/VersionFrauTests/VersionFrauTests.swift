import Foundation
import XCTest
@testable import VersionFrau

final class VersionFrauTests: XCTestCase {
    func testReadsValuesWrittenByTheBuildPhase() throws {
        let bundleDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VersionFrauTests-\(UUID().uuidString).bundle")
        let contentsDirectory = bundleDirectory.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contentsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleDirectory) }

        let infoDictionary: [String: String] = [
            "CFBundleIdentifier": "com.example.versionfrau-tests",
            "CFBundleShortVersionString": "1.0.3",
            "CFBundleVersion": "1000003042",
            "VersionFrauVersionName": "1.0.3.42",
            "VersionFrauFullVersionName": "1.0.3.42",
            "VersionFrauBuildTime": "Oct 24, 2026",
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: infoDictionary, format: .xml, options: 0)
        try plistData.write(to: contentsDirectory.appendingPathComponent("Info.plist"))

        let bundle = try XCTUnwrap(Bundle(url: bundleDirectory))
        let info = VersionFrau.Info(bundle: bundle)
        XCTAssertEqual(info.marketingVersion, "1.0.3")
        XCTAssertEqual(info.bundleVersion, "1000003042")
        XCTAssertEqual(info.versionName, "1.0.3.42")
        XCTAssertEqual(info.fullVersionName, "1.0.3.42")
        XCTAssertEqual(info.buildTime, "Oct 24, 2026")
    }

    func testMissingKeysAreEmpty() {
        let info = VersionFrau.Info(bundle: Bundle(for: VersionFrauTests.self))
        XCTAssertEqual(info.versionName, "")
        XCTAssertEqual(info.buildTime, "")
    }
}
