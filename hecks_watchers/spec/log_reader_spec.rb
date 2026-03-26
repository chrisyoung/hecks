require "spec_helper"

RSpec.describe HecksWatchers::LogReader do
  it "reads and clears the log file" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "tmp"))
      File.write(File.join(dir, "tmp", "watcher.log"), "warning here\n")
      result = nil
      expect { result = described_class.call(dir) }.to output("warning here\n").to_stdout
      expect(result).to eq("warning here")
      expect(File.read(File.join(dir, "tmp", "watcher.log"))).to eq("")
    end
  end

  it "returns nil when log is empty" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "tmp"))
      File.write(File.join(dir, "tmp", "watcher.log"), "")
      expect(described_class.call(dir)).to be_nil
    end
  end

  it "returns nil when log file does not exist" do
    Dir.mktmpdir do |dir|
      expect(described_class.call(dir)).to be_nil
    end
  end
end
