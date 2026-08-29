class Maki < Formula
  desc "Efficient AI coding agent with Lua plugins"
  homepage "https://maki.sh"
  if Hardware::CPU.arm?
    url "https://github.com/tontinton/maki/releases/download/v0.4.12/maki-v0.4.12-aarch64-apple-darwin.tar.gz"
    version "0.4.12"
    sha256 "4bb477085f6ebda698dfe1bb97d99ed91c34c3eb0cdefe36859d3a530f41456b"
  else
    url "https://github.com/tontinton/maki/releases/download/v0.4.12/maki-v0.4.12-x86_64-apple-darwin.tar.gz"
    version "0.4.12"
    sha256 "99515f13a0bab6ec90e83d3ad7ad57d5387c4987eadc862642055c227e7dc71d"
  end
  license "MIT"

  livecheck do
    url "https://github.com/tontinton/maki/releases/latest"
    strategy :github_latest
  end

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
