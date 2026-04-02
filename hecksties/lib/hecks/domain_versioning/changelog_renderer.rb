# Hecks::DomainVersioning::ChangelogRenderer
#
# Renders changelog sections (from ChangelogGenerator) into Markdown.
# Each version gets a header, optional Breaking Changes section,
# and an Additions section.
#
#   sections = ChangelogGenerator.call(base_dir: Dir.pwd)
#   markdown = ChangelogRenderer.render(sections)
#   File.write("DOMAIN_CHANGELOG.md", markdown)
#
module Hecks
  module DomainVersioning
    module ChangelogRenderer
      # Render changelog sections to Markdown string.
      #
      # @param sections [Array<Hash>] from ChangelogGenerator.call
      # @return [String] Markdown-formatted changelog
      def self.render(sections)
        lines = ["# Domain Changelog", ""]

        sections.each do |section|
          lines << render_section(section)
        end

        lines.join("\n")
      end

      # Render a single version section.
      #
      # @param section [Hash] with :version, :tagged_at, :breaking, :additions, :initial
      # @return [String] Markdown for this section
      def self.render_section(section)
        out = []
        date_suffix = section[:tagged_at] ? " (#{section[:tagged_at]})" : ""
        out << "## #{section[:version]}#{date_suffix}"
        out << ""

        if section[:initial]
          out << "Initial release."
          out << ""
          return out.join("\n")
        end

        if section[:breaking].any?
          out << "### Breaking Changes"
          out << ""
          section[:breaking].each { |c| out << "- #{c[:label]}" }
          out << ""
        end

        if section[:additions].any?
          out << "### Additions"
          out << ""
          section[:additions].each { |c| out << "- #{c[:label]}" }
          out << ""
        end

        if section[:breaking].empty? && section[:additions].empty?
          out << "No changes."
          out << ""
        end

        out.join("\n")
      end
    end
  end
end
