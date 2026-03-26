require "spec_helper"
require "hecks_watchers"

RSpec.describe HecksWatchers::Autoloads do
  def setup_project(dir)
    FileUtils.mkdir_p(File.join(dir, "tmp"))
  end

  def watcher_with_staged(dir, files)
    w = described_class.new(project_root: dir)
    w.define_singleton_method(:staged_new_lib_files) { files }
    w
  end

  it "returns empty when no staged files" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      watcher = watcher_with_staged(dir, [])
      expect(watcher.call).to eq([])
    end
  end

  it "warns when a new file is not in autoloads.rb" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      autoloads_dir = File.join(dir, "hecksties", "lib", "hecks")
      FileUtils.mkdir_p(autoloads_dir)
      File.write(File.join(autoloads_dir, "autoloads.rb"), "autoload :Existing, 'hecks/existing'")

      watcher = watcher_with_staged(dir, ["hecks_model/lib/hecks/new_thing.rb"])
      result = nil
      expect { result = watcher.call }.to output(/missing from autoloads/).to_stdout
      expect(result.first).to include("NewThing")
    end
  end

  it "does not warn when the class is registered" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      autoloads_dir = File.join(dir, "hecksties", "lib", "hecks")
      FileUtils.mkdir_p(autoloads_dir)
      File.write(File.join(autoloads_dir, "autoloads.rb"), "autoload :NewThing, 'hecks/new_thing'")

      watcher = watcher_with_staged(dir, ["hecks_model/lib/hecks/new_thing.rb"])
      expect(watcher.call).to eq([])
    end
  end
end
