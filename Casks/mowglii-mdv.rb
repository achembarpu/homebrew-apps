cask "mowglii-mdv" do
  version "1.2.0,144"
  sha256 "722a5306ade2e58333166c70ac1380881deac6f9ae617a1fe2c448f6d06d873e"

  url "https://mowglii.s3.us-east-1.amazonaws.com/mdv/MDV-#{version.csv.second}-#{version.csv.first}.dmg"
  name "MDV"
  desc "Native Markdown viewer with Quick Look and a command-line tool"
  homepage "https://www.mowglii.com/mdv/"

  livecheck do
    url "https://mowglii.s3.us-east-1.amazonaws.com/mdv/appcast.xml"
    strategy :sparkle do |item|
      "#{item.short_version},#{item.version}"
    end
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
