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
    version_dir = File.join(dir, "hecksties", "lib", "hecks")
    FileUtils.mkdir_p(version_dir)
    File.write(File.join(version_dir, "version.rb"), <<~RUBY)
      module Hecks
        VERSION = "0.0.0"
      end
    RUBY
  end

  let(:messages) { [] }
  let(:output) { ->(msg, color) { messages << [msg, color] } }

  describe "COMPONENTS" do
    it "discovers all component gems with gemspecs" do
      expect(described_class::COMPONENTS).to include("hecksties", "bluebook", "hecks_runtime")
      expect(described_class::COMPONENTS).not_to include("examples")
    end
  end

  describe "#bump_version!" do
    it "auto-increments the CalVer version in version.rb" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        builder = described_class.new(dir, output: output)
        allow(builder).to receive(:system).and_return(true)
        builder.build

        version_content = File.read(File.join(dir, "hecksties", "lib", "hecks", "version.rb"))
        today = Date.today.strftime("%Y.%m.%d")
        expect(version_content).to include("VERSION = \"#{today}.1\"")
      end
    end

    it "increments the build number on same-day builds" do
      Dir.mktmpdir do |dir|
        setup_fake_project(dir)
        today = Date.today.strftime("%Y.%m.%d")
        File.write(File.join(dir, ".hecks_version"), "#{today}.3")

        builder = described_class.new(dir, output: output)
        allow(builder).to receive(:system).and_return(true)
        builder.build

        version_content = File.read(File.join(dir, "hecksties", "lib", "hecks", "version.rb"))
        expect(version_content).to include("VERSION = \"#{today}.4\"")
      end
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
        expect(built).to include("gem build hecksties.gemspec")
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
        FileUtils.rm(File.join(dir, "bluebook", "bluebook.gemspec"))
        builder = described_class.new(dir, output: output)
        built = []
        allow(builder).to receive(:system) do |cmd|
          built << cmd
          true
        end
        builder.build
        expect(built).not_to include("gem build bluebook.gemspec")
        expect(built).to include("gem build hecksties.gemspec")
        skipped = messages.find { |m, _| m.include?("Skipping bluebook") }
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
        expected_count = described_class::COMPONENTS.size + 1 # components + meta-gem
        expect(builds.length).to eq(expected_count)
        expect(installs.length).to eq(expected_count)
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

  it "hecks gem can be required and reports a version" do
    expect(defined?(Hecks::VERSION)).to be_truthy
    expect(Hecks::VERSION).to match(/\d+\.\d+/)
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
