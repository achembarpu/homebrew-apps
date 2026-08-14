cask "optcgsim" do
  version "1.42b"
  sha256 "da9919d38255920a33c956b1d4f2db7b4887dd91ba46f4e74fba58677457264d"

  url "https://www.dropbox.com/scl/fi/te0z476tf5wamm827fnm8/1_#{version.tr(".", "_")}_Mac.zip?rlkey=laxvcq3xzof78lzijeprxh12y&st=95sfxiex&dl=1",
      only_path: "#{version}_Mac"
  name "OPTCG Sim"
  desc "Unofficial practice tool for the One Piece Card Game"
  homepage "https://optcgsim.com/"

  depends_on :macos

  app "OPTCGSim.app"

  # The sim is ad-hoc signed, not notarized. The site's own fix (the bundled
  # applescript) only clears quarantine; re-signing locally as well keeps
  # Gatekeeper's first-exec scan happy, matching scripts/add-cask.sh --re-sign.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/OPTCGSim.app"]
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
    The cask pins the site's current Mac build (1.42b), served from the site's
    Dropbox link, which is still named 1_30d_Mac.zip. Since v1.40a the app
    self-updates in-app via its auto-patcher, so newer versions may arrive
    without a cask update.

    Quarantine is cleared and the app is re-signed ad-hoc in postflight; the
    site's own workaround (the bundled applescript) only clears quarantine.
  EOS
end
