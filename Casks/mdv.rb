cask "mdv" do
  version "1.5.1"
  sha256 "c5d305be125f256ced5aed92d492741e6f3b94d249ba0e6da1545dc1477e95c2"

  url "https://github.com/tqbf/mdv/releases/download/v#{version}/mdv-#{version}-macos.zip"
  name "mdv"
  desc "Native Markdown viewer with history, bookmarks, and a TOC sidebar"
  homepage "https://github.com/tqbf/mdv"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura
  depends_on arch: :arm64

  app "mdv.app"

  # The release zip ships AppleDouble (._) junk files inside the bundle, which
  # break the developer signature's seal: Gatekeeper treats the app as damaged
  # and blocks first launch. Clear quarantine and re-sign locally.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/mdv.app"]
    system_command "/usr/bin/codesign",
                   args: ["--force", "--deep", "--sign", "-", "#{appdir}/mdv.app"]
  end

  zap trash: [
    "~/Library/Application Support/mdv",
    "~/Library/Caches/com.mdv.app",
    "~/Library/Preferences/com.mdv.app.plist",
    "~/Library/Saved Application State/com.mdv.app.savedState",
  ]
end
