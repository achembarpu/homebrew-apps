cask "junie" do
  arch arm: "aarch64", intel: "amd64"

  version "3013.5"
  sha256 arm:   "43f6bf76eb616e777da5dd3810d1de490917892f6aa476e7583ed94f5b605278",
         intel: "35ccd05e62ab49abaecf28539e382bc06f5d704e67490676817320f73e286708"

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
