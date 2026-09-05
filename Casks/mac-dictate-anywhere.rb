cask "mac-dictate-anywhere" do
  version "2.8.3"
  sha256 "c37d3af83c7c899670e5cba2b28c344b53104bf899555eef9775e87cb91f835a"

  url "https://github.com/hoomanaskari/mac-dictate-anywhere/releases/download/v#{version}/DictateAnywhere-#{version}.zip"
  name "Dictate Anywhere"
  desc "On-device voice dictation for any app"
  homepage "https://github.com/hoomanaskari/mac-dictate-anywhere"

  livecheck do
    url "https://github.com/hoomanaskari/mac-dictate-anywhere/releases/latest"
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Dictate Anywhere.app"

  zap trash: [
    "~/Library/Preferences/com.pixelforty.dictate-anywhere.plist",
    "~/Library/Saved Application State/com.pixelforty.dictate-anywhere.savedState",
  ]

  caveats <<~EOS
    Dictate Anywhere requires Microphone and Accessibility permissions. Grant
    both permissions in System Settings → Privacy & Security before dictating.

    Speech models are stored in the shared FluidAudio model directory and are
    not removed by uninstall.
  EOS
end
