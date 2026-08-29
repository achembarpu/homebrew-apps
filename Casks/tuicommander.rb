cask "tuicommander" do
  version "1.7.4"
  sha256 "39f6e66d3f2a66a803de0b91e293ed8fb9c9a1d224062602e571ad3bd2262573"

  url "https://github.com/sstraus/tuicommander/releases/download/v#{version}/TUICommander_#{version}_aarch64.dmg"
  name "TUICommander"
  desc "AI-native IDE for orchestrating coding agents"
  homepage "https://github.com/sstraus/tuicommander"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :high_sierra
  depends_on arch: :arm64

  app "TUICommander.app"

  zap trash: [
    "~/Library/Application Support/com.tuic.commander",
    "~/Library/Caches/com.tuic.commander",
    "~/Library/Preferences/com.tuic.commander.plist",
    "~/Library/Saved Application State/com.tuic.commander.savedState",
  ]
end
