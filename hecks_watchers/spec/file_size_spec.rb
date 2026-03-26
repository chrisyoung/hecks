require "spec_helper"
require "hecks_watchers"

RSpec.describe HecksWatchers::FileSize do
  def setup_project(dir)
    FileUtils.mkdir_p(File.join(dir, "tmp"))
    FileUtils.mkdir_p(File.join(dir, "hecks_model", "lib"))
  end

  def write_rb(dir, path, lines)
    full = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, Array.new(lines) { |i| "line_#{i}" }.join("\n"))
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

  it "warns when a file exceeds the limit" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      write_rb(dir, "hecks_model/lib/big.rb", 190)
      watcher = watcher_with_staged(dir, ["hecks_model/lib/big.rb"])
      result = nil
      expect { result = watcher.call }.to output(/approaching 200-line/).to_stdout
      expect(result).not_to be_empty
    end
  end

  it "excludes doc headers from the count" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      header = Array.new(50) { "# comment" }.join("\n") + "\n"
      code = Array.new(190) { |i| "code_#{i}" }.join("\n")
      File.write(File.join(dir, "hecks_model/lib/with_header.rb"), header + code)
      watcher = watcher_with_staged(dir, ["hecks_model/lib/with_header.rb"])
      result = nil
      expect { result = watcher.call }.to output(/approaching/).to_stdout
      expect(result.first).to include("190 lines")
    end
  end
end
