# Hecks::ReadmeGenerator spec
#
# Tests tag replacement, missing content fallback, and auto-generated tables.
#
require "hecks/readme_generator"
require "tmpdir"
require "fileutils"

RSpec.describe Hecks::ReadmeGenerator do
  let(:root) { Dir.mktmpdir("hecks-readme-test") }

  after { FileUtils.rm_rf(root) }

  def write(path, content)
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  describe "#generate" do
    it "replaces content tags with file contents" do
      write("docs/readme_template.md", "Hello {{content:intro}}")
      write("docs/content/intro.md", "Welcome to Hecks")

      described_class.new(root).generate

      expect(File.read(File.join(root, "README.md"))).to eq("Hello Welcome to Hecks")
    end

    it "replaces usage tags with file contents" do
      write("docs/readme_template.md", "{{usage:quick_start}}")
      write("docs/usage/quick_start.md", "Run hecks new")

      described_class.new(root).generate

      expect(File.read(File.join(root, "README.md"))).to eq("Run hecks new")
    end

    it "leaves a TODO comment for missing content files" do
      write("docs/readme_template.md", "{{content:missing}}")

      described_class.new(root).generate

      readme = File.read(File.join(root, "README.md"))
      expect(readme).to include("<!-- TODO: create docs/content/missing.md -->")
    end

    it "replaces features tag with FEATURES.md content (minus title)" do
      write("docs/readme_template.md", "{{features}}")
      write("FEATURES.md", "# Feature List\n\n- Feature one\n- Feature two")

      described_class.new(root).generate

      readme = File.read(File.join(root, "README.md"))
      expect(readme).to include("- Feature one")
      expect(readme).not_to include("# Feature List")
    end

    it "generates a markdown table for validation_rules tag" do
      write("docs/readme_template.md", "{{validation_rules}}")
      write("lib/hecks/validation_rules/naming/command_naming.rb",
        "# Hecks::ValidationRules::Naming::CommandNaming\n#\n# Rejects non-verb command names\n")

      described_class.new(root).generate

      readme = File.read(File.join(root, "README.md"))
      expect(readme).to include("| Rule | Description |")
      expect(readme).to include("| CommandNaming | Rejects non-verb command names |")
    end

    it "generates a markdown table for cli_commands tag" do
      write("docs/readme_template.md", "{{cli_commands}}")
      write("lib/hecks/cli/commands/build.rb",
        "# Hecks::CLI::Domain#build\n#\n# Validates and generates the domain gem.\n#\n")

      described_class.new(root).generate

      readme = File.read(File.join(root, "README.md"))
      expect(readme).to include("| Command | Description |")
      expect(readme).to include("| `hecks build` | Validates and generates the domain gem |")
    end

    it "marks unknown tags with an HTML comment" do
      write("docs/readme_template.md", "{{bogus:thing}}")

      described_class.new(root).generate

      readme = File.read(File.join(root, "README.md"))
      expect(readme).to include("<!-- unknown tag: {{bogus:thing}} -->")
    end

    it "is idempotent — running twice produces the same output" do
      write("docs/readme_template.md", "Hello {{content:intro}} and {{usage:start}}")
      write("docs/content/intro.md", "Welcome")
      write("docs/usage/start.md", "Run it")

      gen = described_class.new(root)
      first = gen.generate
      second = gen.generate

      expect(first).to eq(second)
    end
  end
end
