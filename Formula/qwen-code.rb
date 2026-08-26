class QwenCode < Formula
  desc "Open-source AI coding agent for the terminal"
  homepage "https://qwenlm.github.io/qwen-code-docs/en/users/overview"
  if Hardware::CPU.arm?
    url "https://github.com/QwenLM/qwen-code/releases/download/v0.22.2/qwen-code-darwin-arm64.tar.gz"
    sha256 "d056fd3be53cb6ed24b52c3bf9158c5cbd2ee7e54671e9fd141b1cad9a8390e0"
  else
    url "https://github.com/QwenLM/qwen-code/releases/download/v0.22.2/qwen-code-darwin-x64.tar.gz"
    sha256 "07a2156d85b522dde7a3dc690bee9afaa1a4097b7ebe1cd410c339c76c322b25"
  end
  license "Apache-2.0"

  livecheck do
    url "https://github.com/QwenLM/qwen-code/releases/latest"
    strategy :github_latest
  end

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
