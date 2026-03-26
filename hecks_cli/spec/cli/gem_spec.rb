require "spec_helper"
require "hecks_cli"

RSpec.describe Hecks::GemBuilder do
  def setup_fake_project(dir)
    FileUtils.touch(File.join(dir, "hecks.gemspec"))
    described_class::COMPONENTS.each do |name|
      component_dir = File.join(dir, name)
      FileUtils.mkdir_p(component_dir)
      FileUtils.touch(File.join(component_dir, "#{name}.gemspec"))
    end
  end

  let(:messages) { [] }
  let(:output) { ->(msg, color) { messages << [msg, color] } }

  describe "COMPONENTS" do
    it "lists all component gems in dependency order" do
      expect(described_class::COMPONENTS).to eq(%w[
        hecksties hecks_model hecks_domain hecks_runtime
        hecks_session hecks_cli hecks_persist hecks_watchers
      ])
    end
  end

  describe "#build" do
    it "builds each component then the meta-gem" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        builder = described_class.new(dir, output: output)
        built = []
        allow(builder).to receive(:system) do |cmd|
          built << cmd
          true
        end
        builder.build
        expect(built.first(2)).to eq([
          "gem build hecksties.gemspec",
          "gem build hecks_model.gemspec"
        ])
        expect(built.last).to eq("gem build hecks.gemspec")
      end
    end

    it "stops on first build failure" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        builder = described_class.new(dir, output: output)
        call_count = 0
        allow(builder).to receive(:system) do |_cmd|
          call_count += 1
          false
        end
        builder.build
        expect(call_count).to eq(1)
      end
    end

    it "skips components without a gemspec" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        FileUtils.rm(File.join(dir, "hecks_model", "hecks_model.gemspec"))
        builder = described_class.new(dir, output: output)
        built = []
        allow(builder).to receive(:system) do |cmd|
          built << cmd
          true
        end
        builder.build
        expect(built).not_to include("gem build hecks_model.gemspec")
        expect(built).to include("gem build hecksties.gemspec")
        skipped = messages.find { |m, _| m.include?("Skipping hecks_model") }
        expect(skipped).not_to be_nil
      end
    end
  end

  describe "#install" do
    it "builds, installs, and cleans up each component gem" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        builder = described_class.new(dir, output: output)
        commands = []
        allow(builder).to receive(:system) do |cmd|
          if cmd.start_with?("gem build")
            name = cmd[/gem build (\S+)\.gemspec/, 1]
            gem_dir = name == "hecks" ? dir : File.join(dir, name)
            FileUtils.touch(File.join(gem_dir, "#{name}-0.1.0.gem"))
          end
          commands << cmd
          true
        end
        builder.install
        builds = commands.select { |c| c.start_with?("gem build") }
        installs = commands.select { |c| c.start_with?("gem install") }
        expect(builds.length).to eq(9)
        expect(installs.length).to eq(9)
        expect(builds.last).to eq("gem build hecks.gemspec")
      end
    end

    it "stops when a component install fails" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        builder = described_class.new(dir, output: output)
        call_count = 0
        allow(builder).to receive(:system) do |cmd|
          call_count += 1
          if cmd.start_with?("gem build")
            name = cmd[/gem build (\S+)\.gemspec/, 1]
            FileUtils.touch(File.join(dir, name, "#{name}-0.1.0.gem"))
            true
          else
            false
          end
        end
        builder.install
        expect(call_count).to eq(2)
      end
    end
  end
end

RSpec.describe "gem packaging smoke test" do
  let(:root) { File.expand_path("../../..", __dir__) }

  Hecks::GemBuilder::COMPONENTS.each do |name|
    it "#{name} gemspec includes lib files" do
      component_dir = File.join(root, name)
      gemspec_path = File.join(component_dir, "#{name}.gemspec")
      next unless File.exist?(gemspec_path)
      spec = Dir.chdir(component_dir) { Gem::Specification.load(gemspec_path) }
      lib_files = spec.files.select { |f| f.start_with?("lib/") }
      expect(lib_files).not_to be_empty,
        "#{name}.gemspec packages no lib/ files — installed gem will be broken"
    end
  end

  it "installed hecks gem can be required in a subprocess" do
    result = `ruby -e 'require "hecks"; puts Hecks::VERSION' 2>&1`
    expect($?.success?).to be(true),
      "require 'hecks' failed in subprocess:\n#{result}"
  end
end

RSpec.describe Hecks::CLI::Gem do
  it "delegates build to GemBuilder" do
    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, "hecks.gemspec"))
      cli = described_class.new
      Dir.chdir(dir) do
        builder = instance_double(Hecks::GemBuilder)
        allow(Hecks::GemBuilder).to receive(:new).and_return(builder)
        expect(builder).to receive(:build)
        cli.build
      end
    end
  end

  it "delegates install to GemBuilder" do
    Dir.mktmpdir do |dir|
      FileUtils.touch(File.join(dir, "hecks.gemspec"))
      cli = described_class.new
      Dir.chdir(dir) do
        builder = instance_double(Hecks::GemBuilder)
        allow(Hecks::GemBuilder).to receive(:new).and_return(builder)
        expect(builder).to receive(:install)
        cli.install
      end
    end
  end
end
