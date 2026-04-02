require "spec_helper"
require "hecks_cli"

RSpec.describe "domain changelog generation" do
  before { allow($stdout).to receive(:puts) }

  def write_snapshot(dir, version, date, dsl_content)
    versions_dir = File.join(dir, "db/hecks_versions")
    FileUtils.mkdir_p(versions_dir)
    header = "# Hecks domain snapshot\n# version: #{version}\n# tagged_at: #{date}\n"
    File.write(File.join(versions_dir, "#{version}.rb"), header + dsl_content)
  end

  describe Hecks::DomainVersioning::ChangelogGenerator do
    it "returns empty array when no versions exist" do
      Dir.mktmpdir do |dir|
        result = Hecks::DomainVersioning::ChangelogGenerator.call(base_dir: dir)
        expect(result).to eq([])
      end
    end

    it "marks the first version as initial" do
      Dir.mktmpdir do |dir|
        write_snapshot(dir, "1.0.0", "2026-01-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
          end
        RUBY

        sections = Hecks::DomainVersioning::ChangelogGenerator.call(base_dir: dir)
        expect(sections.size).to eq(1)
        expect(sections.first[:version]).to eq("1.0.0")
        expect(sections.first[:initial]).to be true
      end
    end

    it "classifies additions and breaking changes between versions" do
      Dir.mktmpdir do |dir|
        write_snapshot(dir, "1.0.0", "2026-01-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
          end
        RUBY

        write_snapshot(dir, "2.0.0", "2026-02-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              attribute :color, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
            aggregate "Gadget" do
              attribute :label, String
              command "CreateGadget" do
                attribute :label, String
              end
            end
          end
        RUBY

        sections = Hecks::DomainVersioning::ChangelogGenerator.call(base_dir: dir)
        expect(sections.size).to eq(2)

        newest = sections.first
        expect(newest[:version]).to eq("2.0.0")
        expect(newest[:initial]).to be false
        expect(newest[:additions].size).to be >= 2
        expect(newest[:breaking]).to be_empty
      end
    end

    it "detects breaking changes when attributes are removed" do
      Dir.mktmpdir do |dir|
        write_snapshot(dir, "1.0.0", "2026-01-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              attribute :color, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
          end
        RUBY

        write_snapshot(dir, "2.0.0", "2026-02-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
          end
        RUBY

        sections = Hecks::DomainVersioning::ChangelogGenerator.call(base_dir: dir)
        newest = sections.first
        expect(newest[:breaking].size).to eq(1)
        expect(newest[:breaking].first[:label]).to include("attribute")
      end
    end
  end

  describe Hecks::DomainVersioning::ChangelogRenderer do
    it "renders markdown with version headers and sections" do
      sections = [
        { version: "2.0.0", tagged_at: "2026-02-01", initial: false,
          breaking: [{ label: "- attribute: Widget.color" }],
          additions: [{ label: "+ aggregate: Gadget" }] },
        { version: "1.0.0", tagged_at: "2026-01-01", initial: true,
          breaking: [], additions: [] }
      ]

      md = Hecks::DomainVersioning::ChangelogRenderer.render(sections)
      expect(md).to include("# Domain Changelog")
      expect(md).to include("## 2.0.0 (2026-02-01)")
      expect(md).to include("### Breaking Changes")
      expect(md).to include("- - attribute: Widget.color")
      expect(md).to include("### Additions")
      expect(md).to include("- + aggregate: Gadget")
      expect(md).to include("## 1.0.0 (2026-01-01)")
      expect(md).to include("Initial release.")
    end

    it "renders no-changes section when both lists are empty" do
      sections = [
        { version: "1.1.0", tagged_at: "2026-03-01", initial: false,
          breaking: [], additions: [] }
      ]

      md = Hecks::DomainVersioning::ChangelogRenderer.render(sections)
      expect(md).to include("No changes.")
    end
  end

  describe "hecks changelog CLI command" do
    it "prints changelog to stdout" do
      Dir.mktmpdir do |dir|
        write_snapshot(dir, "1.0.0", "2026-01-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
          end
        RUBY

        Dir.chdir(dir) do
          cli = Hecks::CLI.new
          messages = []
          allow(cli).to receive(:say) { |msg, color| messages << [msg, color] }

          cli.changelog

          text = messages.map(&:first).join("\n")
          expect(text).to include("# Domain Changelog")
          expect(text).to include("## 1.0.0")
          expect(text).to include("Initial release.")
        end
      end
    end

    it "writes changelog to file with --output" do
      Dir.mktmpdir do |dir|
        write_snapshot(dir, "1.0.0", "2026-01-01", <<~RUBY)
          Hecks.domain "Test" do
            aggregate "Widget" do
              attribute :name, String
              command "CreateWidget" do
                attribute :name, String
              end
            end
          end
        RUBY

        Dir.chdir(dir) do
          cli = Hecks::CLI.new([], output: "DOMAIN_CHANGELOG.md")
          messages = []
          allow(cli).to receive(:say) { |msg, color| messages << [msg, color] }

          cli.changelog

          path = File.join(dir, "DOMAIN_CHANGELOG.md")
          expect(File.exist?(path)).to be true
          content = File.read(path)
          expect(content).to include("# Domain Changelog")
          expect(content).to include("## 1.0.0")
        end
      end
    end
  end
end
