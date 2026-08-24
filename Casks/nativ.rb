cask "nativ" do
  version "0.3.4"
  sha256 "deef96a7c3f0a69ed4d88f4fd00811aea139966d8ca13e7a6b4a8973eb6f5e9e"

  url "https://github.com/Blaizzy/nativ/releases/download/v#{version}/Nativ-#{version}.dmg"
  name "Nativ"
  desc "Local AI workspace for running MLX models natively on Apple silicon"
  homepage "https://github.com/Blaizzy/nativ"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
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

    Nativ self-updates in-app via Sparkle; when it does, `brew upgrade --cask
    nativ` will not move you past the version pinned here until this cask is
    bumped.
  EOS
end
