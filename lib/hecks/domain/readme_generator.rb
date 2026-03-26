# Hecks::ReadmeGenerator
#
# Generates README.md from docs/readme_template.md by replacing {{tags}}
# with content from the codebase. Hand-written prose in docs/content/,
# usage examples in docs/usage/, auto-generated tables from code.
#
#   ReadmeGenerator.new(project_root).generate
#
require_relative "../extensions/docs"

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
      when "content"          then read_content("docs/content/#{arg}.md")
      when "usage"            then read_usage("docs/usage/#{arg}.md")
      when "features"         then features
      when "connections"      then connections_section
      when "smalltalk"        then smalltalk
      when "validation_rules" then validation_rules
      when "cli_commands"     then cli_commands
      when "domain_summary"   then domain_summary
      when "domain_dsl"       then domain_dsl
      when "domain_policies"  then domain_policies
      else "<!-- unknown tag: {{#{tag}:#{arg}}} -->"
      end
    end

    def read_content(path)
      full = File.join(@root, path)
      File.exist?(full) ? File.read(full).strip : "<!-- TODO: create #{path} -->"
    end

    # Strip title headers and section headers from usage docs since
    # the template provides its own section structure.
    def read_usage(path)
      full = File.join(@root, path)
      return "<!-- TODO: create #{path} -->" unless File.exist?(full)

      lines = File.readlines(full)
      # Drop the title (# ...) and any blank lines after it
      lines.shift while lines.first&.match?(/\A(#[^#]|\s*$)/)
      # Strip ## sub-headers — template controls structure
      lines.reject! { |l| l.match?(/\A## /) }
      lines.join.strip
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
      Dir[File.join(@root, "lib/hecks_cli/commands/*.rb")].sort.each do |f|
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

    def smalltalk
      require_relative "../session/smalltalk_features"
      lines = ["## Hecks Loves Smalltalk", ""]
      Session::SmalltalkFeatures.all.each do |feature|
        lines << "### #{feature[:name]}"
        lines << ""
        lines << feature[:description]
        lines << ""
        lines << "```ruby"
        lines << feature[:example]
        lines << "```"
        lines << ""
      end
      lines.join("\n").strip
    end

    def connections_section
      categories = {
        persistence: "Persistence",
        realtime: "Real-Time",
        rails: "Rails",
        server: "Servers",
        middleware: "Middleware"
      }
      grouped = ExtensionDocs.by_category
      sections = categories.map do |key, title|
        exts = grouped[key]
        next unless exts&.any?
        rows = exts.map { |e| "| [#{e[:name]}](docs/extensions/#{e[:gem]}.md) | #{e[:description]} | `#{e[:gemfile]}` |" }
        "### #{title}\n\n| Extension | Description | Install |\n|---|---|---|\n#{rows.join("\n")}"
      end.compact
      sections.join("\n\n")
    end

    def load_domain
      @_domain ||= begin
        path = File.join(@root, "hecks_domain.rb")
        return nil unless File.exist?(path)
        Kernel.load(path)
        Hecks.last_domain
      end
    end

    def domain_summary
      domain = load_domain
      return "<!-- no hecks_domain.rb found -->" unless domain

      rows = domain.aggregates.map do |agg|
        cmds = agg.commands.map(&:name).join(", ")
        vos = agg.value_objects.map(&:name).join(", ")
        "| **#{agg.name}** | #{cmds} | #{vos} |"
      end

      header = "| Aggregate | Commands | Value Objects |\n|---|---|---|"
      "#{header}\n#{rows.join("\n")}"
    end

    def domain_dsl
      path = File.join(@root, "hecks_domain.rb")
      return "<!-- no hecks_domain.rb found -->" unless File.exist?(path)

      "```ruby\n#{File.read(path).strip}\n```"
    end

    def domain_policies
      domain = load_domain
      return "<!-- no hecks_domain.rb found -->" unless domain
      return "*None*" if domain.policies.empty?

      rows = domain.policies.map do |p|
        "| **#{p.name}** | #{p.event_name} | #{p.trigger_command} |"
      end

      header = "| Policy | On Event | Triggers |\n|---|---|---|"
      "#{header}\n#{rows.join("\n")}"
    end
  end
end
