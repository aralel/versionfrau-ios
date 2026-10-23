class VersionfrauXcode < Formula
  desc "Automatic version and build numbers for Xcode projects"
  homepage "https://github.com/aralel/versionfrau-xcode"
  # `url` and `sha256` of the latest release are written by scripts/release.sh --formula <version>.
  license "MIT"
  head "https://github.com/aralel/versionfrau-xcode.git", branch: "main"

  depends_on :macos

  def install
    bin.install "bin/versionfrau"
  end

  test do
    assert_equal "1.0.0.0", shell_output("#{bin}/versionfrau print fullVersionName").strip
    ENV["CONFIGURATION"] = "Debug"
    system bin/"versionfrau", "increment"
    assert_equal "1000000001", shell_output("#{bin}/versionfrau print bundleVersion").strip
  end
end
