# typed: strict
# frozen_string_literal: true

# Vendored setup command for the optional local model of the junie cask.
# Wraps JetBrains' official local/install.sh verbatim at a pinned revision,
# exposed as `junie-local-setup`. See the caveats for upstream hardware gates.
class JunieLocal < Formula
  desc "Setup command for Junie's optional local model"
  homepage "https://github.com/jetbrains-junie/junie"
  url "https://raw.githubusercontent.com/jetbrains-junie/junie/e40a9660df4eaf989d5506bf43e5f28df0aa2e65/local/install.sh"
  version "2026.08.17"
  sha256 "9f4b5de1fea745c78c263ba1a5703c184ffac61e155eb05fa21c1e78787ac306"

  def install
    bin.install "install.sh" => "junie-local-setup"
  end

  def caveats
    <<~EOS
      The script is vendored verbatim from JetBrains' junie repo at a pinned
      revision; bumps here are deliberate re-pins, never live fetches.

      Upstream hard-gates the install: Apple M5 or newer, >= 40 GB RAM
      (60 GB recommended), macOS 26+. On first run it downloads several GB
      of engine and Qwen weights into ~/.local/share/junie-local and writes
      model config under ~/.junie — both outside brew management by design.
    EOS
  end

  test do
    assert_path_exists bin/"junie-local-setup"
    system "#{bin}/junie-local-setup", "--help"
  end
end
