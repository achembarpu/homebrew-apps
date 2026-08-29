cask "writer-computer" do
  version "0.5.0"
  sha256 "261a43af0812d24e015694238f047939ac7f19632f7bcd7dae9f632d064e5002"

  url "https://github.com/joelbqz/writer-computer/releases/download/v#{version}/Writer_#{version}_aarch64.dmg"
  name "Writer"
  desc "Native Markdown writing environment"
  homepage "https://github.com/joelbqz/writer-computer"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :catalina
  depends_on arch: :arm64

  app "Writer.app"

  zap trash: [
    "~/Library/Application Support/com.writer-computer",
    "~/Library/Caches/com.writer-computer",
    "~/Library/Preferences/com.writer-computer.plist",
    "~/Library/Saved Application State/com.writer-computer.savedState",
  ]
end
