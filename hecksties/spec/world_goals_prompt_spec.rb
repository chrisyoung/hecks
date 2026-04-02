require "spec_helper"
require "stringio"
require "hecks_cli"

RSpec.describe HecksCLI::WorldGoalsPrompt do
  def fake_shell
    double("shell").tap { |s| allow(s).to receive(:say) }
  end

  def with_stdin(text, tty: true)
    fake = StringIO.new(text)
    allow(fake).to receive(:tty?).and_return(tty)
    original = $stdin
    $stdin = fake
    yield
  ensure
    $stdin = original
  end

  describe ".run" do
    it "returns skip mode for choice 2" do
      with_stdin("2\n") do
        result = described_class.run(shell: fake_shell)
        expect(result[:mode]).to eq(:skip)
      end
    end

    it "returns not_applicable mode for choice 3" do
      with_stdin("3\n") do
        result = described_class.run(shell: fake_shell)
        expect(result[:mode]).to eq(:not_applicable)
      end
    end

    it "returns goals mode for choice 1 with valid goals" do
      with_stdin("1\nprivacy, consent\n") do
        result = described_class.run(shell: fake_shell)
        expect(result[:mode]).to eq(:goals)
        expect(result[:goals]).to eq(%i[privacy consent])
      end
    end

    it "filters invalid goal names" do
      with_stdin("1\nprivacy, bogus, consent\n") do
        result = described_class.run(shell: fake_shell)
        expect(result[:goals]).to eq(%i[privacy consent])
      end
    end
  end

  describe ".parse_goals" do
    it "parses comma-separated goals" do
      expect(described_class.parse_goals("privacy, consent")).to eq(%i[privacy consent])
    end

    it "returns empty array for empty input" do
      expect(described_class.parse_goals("")).to eq([])
    end

    it "filters goals not in VALID_GOALS" do
      expect(described_class.parse_goals("privacy, bogus")).to eq([:privacy])
    end
  end
end
