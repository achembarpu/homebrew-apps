class QwenCode < Formula
  desc "Open-source AI coding agent for the terminal"
  homepage "https://qwenlm.github.io/qwen-code-docs/en/users/overview"
  if Hardware::CPU.arm?
    url "https://github.com/QwenLM/qwen-code/releases/download/v0.23.0/qwen-code-darwin-arm64.tar.gz"
    version "0.23.0"
    sha256 "0e88da71c981deb88bcfc4ac5a67e5b76fa505c830cfcbe942506d1175b4fcfa"
  else
    url "https://github.com/QwenLM/qwen-code/releases/download/v0.23.0/qwen-code-darwin-x64.tar.gz"
    version "0.23.0"
    sha256 "aea7287d1de67b17b13b12f3bc2b80f85f0d46bf95ce02cb04470a11e0296e4d"
  end
  license "Apache-2.0"

  livecheck do
    url "https://github.com/QwenLM/qwen-code/releases/latest"
    strategy :github_latest
  end

  no_autobump! because: :requires_manual_review
  depends_on :macos

  def install
    libexec.install Dir["*"]
    bin.write_exec_script libexec / "bin/qwen"
  end

  def caveats
    <<~EOS
      Qwen Code stores authentication and settings under ~/.qwen. It may also
      create project-local .qwen directories.

      Formula uninstallation does not remove that user data. Remove the
      global settings manually if desired:

        rm -rf ~/.qwen

      Project-local .qwen directories are not managed by Homebrew.
      Updates are managed by `brew upgrade qwen-code`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/qwen --version").chomp
  end
end
