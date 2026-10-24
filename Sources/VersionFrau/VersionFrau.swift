import Foundation

/// The version VersionFrau wrote into the built `Info.plist`.
///
///     Text("Version \(VersionFrau.versionName) — built \(VersionFrau.buildTime)")
public enum VersionFrau {
    /// `CFBundleShortVersionString`, always three-part, e.g. `1.0.4`.
    public static var marketingVersion: String { Info(bundle: .main).marketingVersion }
    /// `CFBundleVersion`, e.g. `1000003042`. Grows with every build and release.
    public static var bundleVersion: String { Info(bundle: .main).bundleVersion }
    /// `1.0.3.42` on debug builds, `1.0.4` on release builds.
    public static var versionName: String { Info(bundle: .main).versionName }
    /// Always four-part, e.g. `1.0.4.0`.
    public static var fullVersionName: String { Info(bundle: .main).fullVersionName }
    /// The build date, e.g. `Oct 24, 2026`.
    public static var buildTime: String { Info(bundle: .main).buildTime }

    /// The values of another bundle, e.g. an app extension's `Bundle(for: SomeClass.self)`.
    public struct Info: Sendable, Equatable {
        public let marketingVersion: String
        public let bundleVersion: String
        public let versionName: String
        public let fullVersionName: String
        public let buildTime: String

        public init(bundle: Bundle) {
            func value(_ key: String) -> String {
                bundle.object(forInfoDictionaryKey: key) as? String ?? ""
            }
            marketingVersion = value("CFBundleShortVersionString")
            bundleVersion = value("CFBundleVersion")
            versionName = value("VersionFrauVersionName")
            fullVersionName = value("VersionFrauFullVersionName")
            buildTime = value("VersionFrauBuildTime")
        }
    }
}
