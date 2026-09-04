class Maki < Formula
  desc "Efficient AI coding agent with Lua plugins"
  homepage "https://maki.sh"
  if Hardware::CPU.arm?
    url "https://github.com/tontinton/maki/releases/download/v0.5.0/maki-v0.5.0-aarch64-apple-darwin.tar.gz"
    version "0.5.0"
    sha256 "2a0ee8a5e76261d3c6cdaf8ea2a3f9264838f42872314f9b5f929d6cf47efdf1"
  else
    url "https://github.com/tontinton/maki/releases/download/v0.5.0/maki-v0.5.0-x86_64-apple-darwin.tar.gz"
    version "0.5.0"
    sha256 "b99758642aac0397fd0091390c186d379897e88fc417ea7bcf23aa768637257e"
  end
  license "MIT"

  livecheck do
    url "https://github.com/tontinton/maki/releases/latest"
    strategy :github_latest
  end

  no_autobump! because: :requires_manual_review
  depends_on :macos

  def install
    bin.install "maki"
  end

  def caveats
    <<~EOS
      Maki stores configuration, sessions, and other user data under
      ~/.config/maki and ~/.local/share/maki.

      Formula uninstallation does not remove that user data. Remove it
      manually if desired:

        rm -rf ~/.config/maki ~/.local/share/maki

      Updates are managed by `brew upgrade maki`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/maki --version").chomp
  end
end
