cask "nativ" do
  version "0.3.2"
  sha256 "9916a8688f41168109df54292a7eca19e4fbd840abf261b2df2273b56d625989"

  url "https://github.com/Blaizzy/nativ/releases/download/v#{version}/Nativ-#{version}.dmg"
  name "Nativ"
  desc "Local AI workspace for running MLX models natively on Apple silicon"
  homepage "https://github.com/Blaizzy/nativ"

  livecheck do
    url "https://github.com/Blaizzy/nativ/releases/latest"
    strategy :github_latest
  end

  depends_on macos: :tahoe
  depends_on arch: :arm64

  app "Nativ.app"

  zap trash: [
    "~/Library/Application Support/Nativ",
    "~/Library/Caches/io.github.blaizzy.nativ",
    "~/Library/Caches/Nativ",
    "~/Library/Preferences/io.github.blaizzy.nativ.plist",
  ]

  caveats <<~EOS
    Requires an Apple silicon Mac on macOS 26 or newer (enforced by the cask's
    depends_on).

    First launch walks you through a setup wizard: choose or download a model,
    optionally generate an API key for the local server, and grant microphone,
    accessibility, and screen recording permissions.

    macOS may silently drop the Accessibility grant after the app bundle is
    replaced (brew upgrade). If the global dictation shortcut stops working,
    toggle Nativ off and on in System Settings → Privacy & Security →
    Accessibility.

    Models download to the Hugging Face cache (~/.cache/huggingface/hub by
    default, or wherever HF_HUB_CACHE/HF_HOME points). The cask's zap does not
    delete that shared cache.
  EOS
end
