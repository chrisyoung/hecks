require "spec_helper"

RSpec.describe HecksWatchers::Runner do
  def setup_project(dir)
    FileUtils.mkdir_p(File.join(dir, "tmp"))
    FileUtils.mkdir_p(File.join(dir, "hecks_model", "lib"))
  end

  it "detects new files on check_once" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      runner = described_class.new(project_root: dir)
      # Prime the snapshot
      runner.instance_variable_set(:@snapshot, {})

      File.write(File.join(dir, "hecks_model", "lib", "new.rb"), "# new")
      result = nil
      expect { result = runner.check_once }.to output(/1 file.*changed/).to_stdout
      expect(result).to include("hecks_model/lib/new.rb")
    end
  end

  it "returns empty when nothing changed" do
    Dir.mktmpdir do |dir|
      setup_project(dir)
      File.write(File.join(dir, "hecks_model", "lib", "stable.rb"), "# stable")
      runner = described_class.new(project_root: dir)
      # Prime with current state
      runner.send(:instance_variable_set, :@snapshot, runner.send(:snapshot_files))
      expect(runner.check_once).to eq([])
    end
  end
end
