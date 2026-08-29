cask "podium" do
  arch arm: "aarch64", intel: "x64"

  version "0.1.0"
  sha256 arm:   "ce89e7346279dc908851f8fded5466de8ebd08594bc6070c80e02dfb9e27e13f",
         intel: "cd74bbe38bf939f1a2de18ffb1f37d2f0ede1a1175bb11e2a961874247a95d4e"

  url "https://github.com/madeinorbit/podium/releases/download/v#{version}/Podium_#{version}_#{arch}.dmg"
  name "Podium"
  desc "Multi-agent orchestrator for coding agents"
  homepage "https://github.com/madeinorbit/podium"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :big_sur

  app "Podium.app"

  zap trash: [
    "~/Library/Application Support/app.podium.desktop",
    "~/Library/Caches/app.podium.desktop",
    "~/Library/Preferences/app.podium.desktop.plist",
    "~/Library/Saved Application State/app.podium.desktop.savedState",
  ]

  caveats <<~EOS
    Podium runs agent CLIs through persistent terminal sessions. Install and
    authenticate the agent CLIs you want to use separately.
  EOS
end
