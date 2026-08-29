cask "clearly" do
  version "3.3.0"
  sha256 "322831ce5fc8a70314cfc21c484b7af034142a32d2bf6f00a5a5926c642534e4"

  url "https://github.com/Shpigford/clearly/releases/download/v#{version}/Clearly.dmg"
  name "Clearly"
  desc "Native Markdown editor with live preview"
  homepage "https://clearly.md/"

  livecheck do
    url "https://clearly.md/appcast.xml"
    strategy :sparkle
  end

  auto_updates true
  depends_on macos: :sequoia

  app "Clearly.app"

  zap trash: [
    "~/Library/Application Support/Scratchpads",
    "~/Library/Preferences/com.sabotage.clearly.plist",
    "~/Library/Saved Application State/com.sabotage.clearly.savedState",
  ]

  caveats <<~EOS
    Clearly requires macOS 15 (Sequoia) or later.

    Clearly includes an optional command-line tool that can be installed from
    the app's Settings. The tool is linked into ~/.local/bin, which must be in
    your PATH.
  EOS
end
