class QwenCode < Formula
  desc "Open-source AI coding agent for the terminal"
  homepage "https://qwenlm.github.io/qwen-code-docs/en/users/overview"
  if Hardware::CPU.arm?
    url "https://github.com/QwenLM/qwen-code/releases/download/v0.22.3/qwen-code-darwin-arm64.tar.gz"
    version "0.22.3"
    sha256 "c1909e12b7c8bd9abe669c09487fdf65ef8b2d60cc04755fead0dd8ee0ce4152"
  else
    url "https://github.com/QwenLM/qwen-code/releases/download/v0.22.3/qwen-code-darwin-x64.tar.gz"
    version "0.22.3"
    sha256 "aa90b0d1b51d9677091fcbb98f252aa11cff5e7645ba6cf39b6d5f33a1be98ee"
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
