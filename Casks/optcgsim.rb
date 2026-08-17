cask "optcgsim" do
  version "1.42c"
  sha256 "acae86f45c3930076aadf4ad4b00f33bdc1bcfa9f00378ee47fa34e54e458841"

  url "https://www.dropbox.com/scl/fi/te0z476tf5wamm827fnm8/1_#{version.tr(".", "_")}_Mac.zip?rlkey=laxvcq3xzof78lzijeprxh12y&st=95sfxiex&dl=1",
      only_path: "#{version}_Mac"
  name "OPTCG Sim"
  desc "Unofficial practice tool for the One Piece Card Game"
  homepage "https://optcgsim.com/"

  depends_on :macos

  app "OPTCGSim.app"

  # The sim is ad-hoc signed, not notarized. The site's own fix (the bundled
  # applescript) clears quarantine and restores execute bits on the MacOS
  # binaries; postflight does both of those plus an ad-hoc re-sign to keep
  # Gatekeeper's first-exec scan happy, matching scripts/add-cask.sh --re-sign.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/OPTCGSim.app"]
    # The Windows-built zip stores no exec bits, so restore them on the
    # binaries the bundled applescript chmods (system_command does not
    # shell-expand globs, so expand them in Ruby).
    app_root = "#{appdir}/OPTCGSim.app"
    macos_dir = "#{app_root}/Contents/MacOS"
    bounty_macos_dir = "#{app_root}/Contents/Resources/Data/StreamingAssets/OPBounty/mac/OPBounty.app/Contents/MacOS"
    system_command "/bin/chmod",
                   args: ["+x"] + Dir.glob("#{macos_dir}/*") + Dir.glob("#{bounty_macos_dir}/*")
    system_command "/usr/bin/codesign",
                   args: ["--force", "--deep", "--sign", "-", "#{appdir}/OPTCGSim.app"]
  end

  zap trash: [
    "~/Library/Application Support/Batsu/OPTCGSim",
    "~/Library/Caches/Batsu/OPTCGSim",
    "~/Library/Logs/Batsu/OPTCGSim",
    "~/Library/Preferences/com.Batsu.OPTCGSim.plist",
    "~/Library/Saved Application State/com.Batsu.OPTCGSim.savedState",
  ]

  caveats <<~EOS
    The cask pins the site's current Mac build (1.42c), served from the site's
    Dropbox link, which is still named 1_30d_Mac.zip. Since v1.40a the app
    self-updates in-app via its auto-patcher, so newer versions may arrive
    without a cask update.

    The bundled applescript clears quarantine and restores execute bits on the
    app's MacOS binaries; postflight does both of those plus an ad-hoc
    re-sign. On macOS 26 (Tahoe) the non-notarized build may still draw a
    one-time Gatekeeper approval despite the re-sign; that is a
    developer-side limitation, not something the cask can fix.
  EOS
end
