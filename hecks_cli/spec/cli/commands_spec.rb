require "spec_helper"
require "tmpdir"
require "fileutils"

# Hecks CLI Command Integration Tests
#
# Tests each `hecks domain` subcommand by invoking Hecks::CLI.start
# with captured stdout. Uses a temp directory with a minimal domain.
RSpec.describe "CLI commands" do
  let(:tmpdir) { Dir.mktmpdir("hecks-cli-") }
  let(:domain_rb) do
    <<~RUBY
      Hecks.domain "Widget" do
        aggregate "Widget" do
          attribute :name, String
          attribute :color, String

          command "CreateWidget" do
            attribute :name, String
            attribute :color, String
          end

          command "PaintWidget" do
            attribute :widget_id, String
            attribute :color, String
          end
        end

        aggregate "Part" do
          attribute :label, String

          command "CreatePart" do
            attribute :label, String
          end
        end
      end
    RUBY
  end

  before do
    File.write(File.join(tmpdir, "hecks_domain.rb"), domain_rb)
    File.write(File.join(tmpdir, ".hecks_version"), "0.0.0")
  end

  after do
    FileUtils.rm_rf(tmpdir)
    # Clean up global state from generate:migrations
    Hecks::Migrations::MigrationStrategy.registry.delete(:sql)
  end

  def run_cli(*args)
    output = StringIO.new
    $stdout = output
    $stderr = output
    Hecks::CLI.start(args)
    $stdout = STDOUT
    $stderr = STDERR
    output.string
  rescue SystemExit
    $stdout = STDOUT
    $stderr = STDERR
    output.string
  end

  describe "validate" do
    it "reports a valid domain" do
      out = run_cli("domain", "validate", "--domain", tmpdir)
      expect(out).to include("Domain is valid")
      expect(out).to include("Widget")
    end
  end

  describe "build" do
    it "generates the domain gem" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "build", "--domain", tmpdir)
        expect(out).to include("Built widget_domain")
      end
    end
  end

  describe "version" do
    it "shows hecks version without --domain" do
      out = run_cli("domain", "version")
      expect(out).to include("hecks")
      expect(out).to include(Hecks::VERSION)
    end

    it "shows domain version with --domain" do
      out = run_cli("domain", "version", "--domain", tmpdir)
      expect(out).to include("Widget")
    end
  end

  describe "dump" do
    it "dumps glossary" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "dump", "glossary", "--domain", tmpdir)
        expect(out).to include("glossary.md")
      end
    end
  end

  describe "llms" do
    it "generates AI-readable summary" do
      out = run_cli("domain", "llms", "--domain", tmpdir)
      expect(out).to include("Widget")
      expect(out).to include("CreateWidget")
    end
  end

  describe "info" do
    it "shows domain info" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "info")
        expect(out).to include("Widget")
      end
    end
  end

  describe "context_map" do
    it "shows bounded contexts" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "context_map")
        expect(out).to include("Context Map")
      end
    end
  end

  describe "promote" do
    it "extracts an aggregate into its own domain" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "promote", "Part")
        expect(out).to include("Wrote part_domain.rb")
        expect(out).to include("Part removed from Widget")
        expect(File.exist?(File.join(tmpdir, "part_domain.rb"))).to be true

        content = File.read(File.join(tmpdir, "part_domain.rb"))
        expect(content).to include('Hecks.domain "Part"')

        updated = File.read(File.join(tmpdir, "hecks_domain.rb"))
        expect(updated).not_to include('"Part"')
        expect(updated).to include("Widget")
      end
    end
  end

  describe "init" do
    it "creates domain files in a new directory" do
      new_dir = File.join(tmpdir, "fresh")
      FileUtils.mkdir_p(new_dir)
      Dir.chdir(new_dir) do
        out = run_cli("domain", "init", "Blog")
        expect(out).to include("Created hecks_domain.rb")
        expect(File.exist?(File.join(new_dir, "hecks_domain.rb"))).to be true
      end
    end
  end

  describe "generate:config" do
    it "generates config output" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "generate:config")
        expect(out).to include("Widget")
      end
    end
  end

  describe "generate:sinatra" do
    it "scaffolds a sinatra app" do
      Dir.chdir(tmpdir) do
        out = run_cli("domain", "generate:sinatra", "--domain", tmpdir)
        expect(out).to include("Generated Sinatra app")
      end
    end
  end

  describe "generate:migrations" do
    it "generates SQL migration" do
      mig_dir = File.join(tmpdir, "mig_test")
      FileUtils.mkdir_p(mig_dir)
      FileUtils.cp(File.join(tmpdir, "hecks_domain.rb"), File.join(mig_dir, "hecks_domain.rb"))
      Dir.chdir(mig_dir) do
        out = run_cli("domain", "generate:migrations", "--domain", mig_dir)
        expect(out).to include("Generated")
        expect(out).to include("CREATE TABLE")
      end
    end
  end

  describe "tree" do
    it "prints command tree" do
      out = run_cli("domain", "tree")
      expect(out).to include("build")
      expect(out).to include("validate")
    end
  end

  describe "list" do
    it "lists installed domains" do
      out = run_cli("domain", "list")
      expect(out).to include("Installed")
    end
  end
end
