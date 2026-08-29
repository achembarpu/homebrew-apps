cask "mowglii-mdv" do
  version "1.1.13"
  sha256 "37386b21e7f031730c2eab6b588a50ea1e6ba1e5cfab44ed255212014b585383"

  url "https://mowglii.s3.us-east-1.amazonaws.com/mdv/MDV-143-1.1.13.dmg"
  name "MDV"
  desc "Native Markdown viewer with Quick Look and a command-line tool"
  homepage "https://www.mowglii.com/mdv/"

  livecheck do
    url "https://mowglii.s3.us-east-1.amazonaws.com/mdv/appcast.xml"
    strategy :sparkle
  end

  depends_on macos: :ventura

  app "MDV.app"

  zap trash: [
    "~/Library/Preferences/com.mowglii.MDV.plist",
    "~/Library/Saved Application State/com.mowglii.MDV.savedState",
  ]

  caveats <<~EOS
    MDV includes an optional command line tool. Install it from the MDV menu
    after moving the app to the Applications folder.

    The command line tool is linked into ~/.local/bin, which must be in your PATH.
  EOS
end
