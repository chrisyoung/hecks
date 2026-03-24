# Hecks::ReadmeGenerator
#
# Generates README.md from docs/readme_template.md by replacing {{tags}}
# with content from the codebase. Hand-written prose in docs/content/,
# usage examples in docs/usage/, auto-generated tables from code.
#
#   ReadmeGenerator.new(project_root).generate
#
module Hecks
  class ReadmeGenerator
    def initialize(root)
      @root = root
    end

    def generate
      template = File.read(File.join(@root, "docs/readme_template.md"))
      output = template.gsub(/\{\{(\w+)(?::(\w+))?\}\}/) { dispatch($1, $2) }
      File.write(File.join(@root, "README.md"), output)
      output
    end

    private

    def dispatch(tag, arg)
      case tag
      when "content"          then read_file("docs/content/#{arg}.md")
      when "usage"            then read_file("docs/usage/#{arg}.md")
      when "features"         then features
      when "validation_rules" then validation_rules
      when "cli_commands"     then cli_commands
      else "<!-- unknown tag: {{#{tag}:#{arg}}} -->"
      end
    end

    def read_file(path)
      full = File.join(@root, path)
      File.exist?(full) ? File.read(full).strip : "<!-- TODO: create #{path} -->"
    end

    def features
      path = File.join(@root, "FEATURES.md")
      return "<!-- TODO: create FEATURES.md -->" unless File.exist?(path)

      content = File.read(path)
      content.sub(/\A# .*\n+/, "").strip
    end

    def validation_rules
      rules = []
      Dir[File.join(@root, "lib/hecks/validation_rules/**/*.rb")].sort.each do |f|
        lines = File.readlines(f)
        next unless lines.first&.start_with?("# Hecks::")

        name = lines.first.sub("# ", "").strip
        next if name.end_with?("::Naming", "::References", "::Structure")
        next if name.include?("BaseRule")

        # Description is the first non-blank comment line after the class name
        desc_line = lines[1..].find { |l| l.match?(/^# \S/) }
        desc = desc_line&.sub(/^#\s*/, "")&.strip || ""
        desc = desc.split(/\.(\s|$)/).first&.strip || desc
        short_name = name.split("::").last
        rules << "| #{short_name} | #{desc} |"
      end
      "| Rule | Description |\n|---|---|\n#{rules.join("\n")}"
    end

    def cli_commands
      commands = []
      Dir[File.join(@root, "lib/hecks/cli/commands/*.rb")].sort.each do |f|
        lines = File.readlines(f)
        next unless lines.first&.start_with?("# Hecks::")

        desc_line = lines[1..].find { |l| l.match?(/^# \S/) }
        desc = desc_line&.sub(/^#\s*/, "")&.strip || ""
        desc = desc.split(/\.(\s|$)/).first&.strip || desc
        name = File.basename(f, ".rb").gsub("_", " ")
        commands << "| `hecks #{name}` | #{desc} |"
      end
      "| Command | Description |\n|---|---|\n#{commands.join("\n")}"
    end
  end
end
