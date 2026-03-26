require "spec_helper"

RSpec.describe HecksWatchers::CrossRequire do
  def setup_project(dir)
    FileUtils.mkdir_p(File.join(dir, "tmp"))
  end

  it "returns empty when no staged files" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      watcher = described_class.new(project_root: dir)
      allow(watcher).to receive(:`).and_return("")
      expect(watcher.call).to eq([])
    end
  end

  it "detects cross-component require_relative" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      comp = File.join(dir, "hecks_cli", "lib")
      FileUtils.mkdir_p(comp)
      bad_line = "require" + '_relative "../../hecks_model/lib/foo"'
      File.write(File.join(comp, "bad.rb"), bad_line)
      watcher = described_class.new(project_root: dir)
      allow(watcher).to receive(:`).and_return("hecks_cli/lib/bad.rb\n")
      result = nil
      expect { result = watcher.call }.to output(/BLOCKED/).to_stdout
      expect(result).not_to be_empty
    end
  end

  it "allows same-component require_relative" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      comp = File.join(dir, "hecks_cli", "lib")
      FileUtils.mkdir_p(comp)
      File.write(File.join(comp, "ok.rb"), "require" + '_relative "helper"')
      watcher = described_class.new(project_root: dir)
      allow(watcher).to receive(:`).and_return("hecks_cli/lib/ok.rb\n")
      expect(watcher.call).to eq([])
    end
  end
end
