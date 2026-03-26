require "spec_helper"

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

  it "returns empty when no staged files" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      watcher = described_class.new(project_root: dir)
      allow(watcher).to receive(:`).and_return("")
      expect(watcher.call).to eq([])
    end
  end

  it "warns when a file exceeds the limit" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      write_rb(dir, "hecks_model/lib/big.rb", 190)
      watcher = described_class.new(project_root: dir)
      allow(watcher).to receive(:`).and_return("hecks_model/lib/big.rb\n")
      result = nil
      expect { result = watcher.call }.to output(/approaching 200-line/).to_stdout
      expect(result).not_to be_empty
    end
  end

  it "excludes doc headers from the count" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      header = Array.new(50) { "# comment" }.join("\n") + "\n"
      code = Array.new(170) { |i| "code_#{i}" }.join("\n")
      File.write(File.join(dir, "hecks_model/lib/with_header.rb"), header + code)
      watcher = described_class.new(project_root: dir)
      allow(watcher).to receive(:`).and_return("hecks_model/lib/with_header.rb\n")
      result = nil
      expect { result = watcher.call }.to output(/approaching/).to_stdout
      expect(result.first).to include("170 lines")
    end
  end
end
