require "spec_helper"

RSpec.describe HecksWatchers::Logger do
  it "writes to stdout and the log file" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "tmp"))
      logger = described_class.new(dir)
      expect { logger.log("hello") }.to output("hello\n").to_stdout
      content = File.read(File.join(dir, "tmp", "watcher.log"))
      expect(content.strip).to eq("hello")
    end
  end

  it "appends multiple messages" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "tmp"))
      logger = described_class.new(dir)
      expect do
        logger.log("one")
        logger.log("two")
      end.to output("one\ntwo\n").to_stdout
      content = File.read(File.join(dir, "tmp", "watcher.log"))
      expect(content).to include("one")
      expect(content).to include("two")
    end
  end
end
