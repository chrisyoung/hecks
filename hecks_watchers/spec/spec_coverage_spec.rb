require "spec_helper"
require "hecks_watchers"

RSpec.describe HecksWatchers::SpecCoverage do
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

  it "warns when a new lib file has no spec" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      lib_dir = File.join(dir, "hecks_model", "lib", "hecks")
      FileUtils.mkdir_p(lib_dir)
      File.write(File.join(lib_dir, "widget.rb"), "# widget")

      watcher = watcher_with_staged(dir, ["hecks_model/lib/hecks/widget.rb"])
      result = nil
      expect { result = watcher.call }.to output(/without specs/).to_stdout
      expect(result.first).to include("widget")
    end
  end

  it "does not warn when a matching spec exists" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      lib_dir = File.join(dir, "hecks_model", "lib", "hecks")
      spec_dir = File.join(dir, "hecks_model", "spec")
      FileUtils.mkdir_p(lib_dir)
      FileUtils.mkdir_p(spec_dir)
      File.write(File.join(lib_dir, "widget.rb"), "# widget")
      File.write(File.join(spec_dir, "widget_spec.rb"), "# spec")

      watcher = watcher_with_staged(dir, ["hecks_model/lib/hecks/widget.rb"])
      expect(watcher.call).to eq([])
    end
  end
end
