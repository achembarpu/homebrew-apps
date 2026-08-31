cask "junie" do
  arch arm: "aarch64", intel: "amd64"

  version "3013.3"
  sha256 arm:   "dbf481b9fca76e4d0c1e57a79ecb492b11b38e6f2081809437a1bcefafb2f9ac",
         intel: "a4145b301bcd8434c891457a8f7bbe10d6bd36612e4941318b5662efaf94227d"

  url "https://github.com/JetBrains/junie/releases/download/#{version}/junie-release-#{version}-macos-#{arch}.zip"
  name "Junie"
  desc "AI coding agent CLI by JetBrains"
  homepage "https://www.jetbrains.com/junie/"

  # The GitHub latest release is a nightly build, not the stable release
  # channel used by this cask. Check JetBrains' stable update manifest instead.
  livecheck do
    url "https://raw.githubusercontent.com/jetbrains-junie/junie/main/update-info.jsonl"
    regex(/"version":"(\d+(?:\.\d+)+)".*"platform":"macos-aarch64"/)
    strategy :page_match
  end

  depends_on :macos

  app "Applications/junie.app"
  binary "#{appdir}/junie.app/Contents/MacOS/junie"

  zap trash: [
    "~/.junie",
    "~/.local/share/junie",
  ]

  caveats <<~EOS
    Junie ships Developer ID signed and notarized; no re-sign needed. The
    binary linked onto PATH lives inside the app bundle.

    Updates come from `brew upgrade --cask junie`. Junie's built-in
    self-updater expects JetBrains' own shim layout (~/.local/bin/junie),
    which this cask does not install.
  EOS
end
