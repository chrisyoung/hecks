require "spec_helper"
require "hecks_watcher_agent"
require "tmpdir"

RSpec.describe HecksWatcherAgent::Agent do
  let(:tmpdir) { Dir.mktmpdir("watcher-agent-") }
  let(:agent) { described_class.new(project_root: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#call" do
    it "reports no issues when log is empty" do
      expect { agent.call }.to output(/No watcher issues found/).to_stdout
    end

    it "reports no issues when log file is missing" do
      expect { agent.call }.to output(/No watcher issues found/).to_stdout
    end
  end

  describe "parse_log" do
    it "parses file size warnings" do
      FileUtils.mkdir_p(File.join(tmpdir, "tmp"))
      File.write(File.join(tmpdir, "tmp/watcher.log"), <<~LOG)

        ⚠  Files approaching 200-line code limit:
          hecks_static/lib/hecks_static/generators/ui_generator.rb: 192 lines (limit: 200)

      LOG

      issues = agent.send(:parse_log)
      expect(issues.size).to eq(1)
      expect(issues.first[:type]).to eq(:file_size)
      expect(issues.first[:message]).to include("ui_generator.rb")
    end

    it "parses autoloads warnings" do
      FileUtils.mkdir_p(File.join(tmpdir, "tmp"))
      File.write(File.join(tmpdir, "tmp/watcher.log"), <<~LOG)

        📦 New files possibly missing from autoloads.rb:
          Generator (hecks_domain/lib/hecks/generator.rb)
        Check hecksties/lib/hecks/autoloads.rb

      LOG

      issues = agent.send(:parse_log)
      expect(issues.size).to eq(1)
      expect(issues.first[:type]).to eq(:autoloads)
      expect(issues.first[:message]).to include("Generator")
    end

    it "parses spec coverage warnings" do
      FileUtils.mkdir_p(File.join(tmpdir, "tmp"))
      File.write(File.join(tmpdir, "tmp/watcher.log"), <<~LOG)

        📋 New lib files without specs:
          hecks_domain/lib/hecks/generator.rb → expected hecks_domain/spec/generator_spec.rb

      LOG

      issues = agent.send(:parse_log)
      expect(issues.size).to eq(1)
      expect(issues.first[:type]).to eq(:spec_coverage)
    end

    it "parses doc reminders" do
      FileUtils.mkdir_p(File.join(tmpdir, "tmp"))
      File.write(File.join(tmpdir, "tmp/watcher.log"), <<~LOG)

        📝 Doc reminders:
          FEATURES.md — new lib files added but FEATURES.md not updated

      LOG

      issues = agent.send(:parse_log)
      expect(issues.size).to eq(1)
      expect(issues.first[:type]).to eq(:doc_reminder)
    end

    it "parses multiple issue types" do
      FileUtils.mkdir_p(File.join(tmpdir, "tmp"))
      File.write(File.join(tmpdir, "tmp/watcher.log"), <<~LOG)

        ⚠  Files approaching 200-line code limit:
          big_file.rb: 195 lines (limit: 200)

        📋 New lib files without specs:
          new_file.rb → expected spec/new_file_spec.rb

      LOG

      issues = agent.send(:parse_log)
      expect(issues.size).to eq(2)
      expect(issues.map { |i| i[:type] }).to eq([:file_size, :spec_coverage])
    end
  end

  describe "fix_spec_coverage" do
    it "generates a skeleton spec file" do
      issue = { type: :spec_coverage, message: "hecks_domain/lib/hecks/generator.rb → expected hecks_domain/spec/generator_spec.rb" }
      agent.send(:fix_spec_coverage, issue)

      spec_path = File.join(tmpdir, "hecks_domain/spec/generator_spec.rb")
      expect(File.exist?(spec_path)).to be true
      expect(File.read(spec_path)).to include("RSpec.describe Generator")
    end
  end
end
