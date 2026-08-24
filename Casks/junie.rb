cask "junie" do
  arch arm: "aarch64", intel: "amd64"

  version "2929.5"
  sha256 arm:   "5d4463a37c1f4fd5d1f972f7aa954ef9159db532017236c32597accbfffb8285",
         intel: "e9c454187b7d878be55de192e76ea9257d28c4e18ad7dfec4f00ef7c9c04dcb8"

  url "https://github.com/JetBrains/junie/releases/download/#{version}/junie-release-#{version}-macos-#{arch}.zip"
  name "Junie"
  desc "AI coding agent CLI by JetBrains"
  homepage "https://www.jetbrains.com/junie/"

  livecheck do
    url :url
    strategy :github_latest
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
