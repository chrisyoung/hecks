require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Versioner do
  let(:tmpdir) { Dir.mktmpdir }
  subject(:versioner) { described_class.new(tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  let(:today) { Date.today.strftime("%Y.%m.%d") }

  describe "#current" do
    it "returns nil when no version file exists" do
      expect(versioner.current).to be_nil
    end

    it "reads existing version" do
      File.write(File.join(tmpdir, ".hecks_version"), "2026.03.20.1")
      expect(versioner.current).to eq("2026.03.20.1")
    end
  end

  describe "#next" do
    it "starts at build 1 for today" do
      expect(versioner.next).to eq("#{today}.1")
    end

    it "increments the build number on same day" do
      versioner.next
      expect(versioner.next).to eq("#{today}.2")
    end

    it "keeps incrementing" do
      versioner.next  # .1
      versioner.next  # .2
      expect(versioner.next).to eq("#{today}.3")
    end

    it "resets to 1 on a new day" do
      File.write(File.join(tmpdir, ".hecks_version"), "2020.01.01.5")
      expect(versioner.next).to eq("#{today}.1")
    end

    it "persists the version" do
      version = versioner.next
      expect(versioner.current).to eq(version)
    end
  end
end
