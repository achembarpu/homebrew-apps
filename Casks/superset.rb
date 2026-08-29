cask "superset" do
  arch arm: "arm64", intel: "x64"

  version "1.25.0"
  sha256 arm:   "51da213df75f03fd5e3e1c8048f185f4622977ce8d08960a1bbb05b0bef5a263",
         intel: "764acad91d35a47b85e3e22a300fce8d614479f596981c3496cbfff2a5684296"

  url "https://github.com/superset-sh/superset/releases/download/desktop-v#{version}/Superset-#{version}-#{arch}-mac.zip"
  name "Superset"
  desc "Agentic IDE for orchestrating coding agents"
  homepage "https://github.com/superset-sh/superset"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :monterey

  app "Superset.app"

  zap trash: [
    "~/Library/Application Support/com.superset.desktop",
    "~/Library/Caches/com.superset.desktop",
    "~/Library/Preferences/com.superset.desktop.plist",
    "~/Library/Saved Application State/com.superset.desktop.savedState",
  ]
end
