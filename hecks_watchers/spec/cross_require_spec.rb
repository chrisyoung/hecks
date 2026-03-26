require "spec_helper"
require "hecks_watchers"

RSpec.describe HecksWatchers::CrossRequire do
  def setup_project(dir)
    FileUtils.mkdir_p(File.join(dir, "tmp"))
  end

  def watcher_with_staged(dir, files)
    w = described_class.new(project_root: dir)
    w.define_singleton_method(:staged_rb_files) { files }
    w
  end

  it "returns empty when no staged files" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      watcher = watcher_with_staged(dir, [])
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
      watcher = watcher_with_staged(dir, ["hecks_cli/lib/bad.rb"])
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
      watcher = watcher_with_staged(dir, ["hecks_cli/lib/ok.rb"])
      expect(watcher.call).to eq([])
    end
  end
end
