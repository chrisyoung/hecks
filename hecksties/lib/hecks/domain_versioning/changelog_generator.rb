# Hecks::DomainVersioning::ChangelogGenerator
#
# Generates a Markdown changelog from domain version diffs. Compares
# consecutive tagged snapshots and classifies changes as breaking or
# non-breaking. Output is a multi-version changelog string.
#
#   md = ChangelogGenerator.generate(base_dir: Dir.pwd)
#   File.write("DOMAIN_CHANGELOG.md", md)
#
module Hecks
  module DomainVersioning
    module ChangelogGenerator
      # Generate a full Markdown changelog from all tagged version diffs.
      #
      # @param base_dir [String] project root directory
      # @return [String] Markdown changelog content
      def self.generate(base_dir: Dir.pwd)
        versions = DomainVersioning.log(base_dir: base_dir)
        return "# Domain Changelog\n\nNo tagged versions found.\n" if versions.empty?

        lines = ["# Domain Changelog", ""]

        pairs = versions.each_cons(2).to_a.reverse
        if pairs.empty?
          lines << "## #{versions.first[:version]}"
          lines << ""
          lines << "Initial version."
          lines << ""
          return lines.join("\n")
        end

        pairs.each do |older, newer|
          old_domain = DomainVersioning.load_version(older[:version], base_dir: base_dir)
          new_domain = DomainVersioning.load_version(newer[:version], base_dir: base_dir)
          next unless old_domain && new_domain

          lines.concat(version_section(newer[:version], newer[:tagged_at], old_domain, new_domain))
        end

        # First version section
        lines << "## #{versions.last[:version]}"
        lines << ""
        lines << "Initial version."
        lines << ""

        lines.join("\n")
      end

      # Generate a changelog section for a single version.
      #
      # @param old_domain [Hecks::DomainModel::Domain]
      # @param new_domain [Hecks::DomainModel::Domain]
      # @return [String] single version Markdown section
      def self.generate_diff(old_domain, new_domain, version: "unreleased")
        lines = ["## #{version}", ""]
        changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
        classified = BreakingClassifier.classify(changes)

        if classified.empty?
          lines << "No changes."
        else
          breaking, non_breaking = classified.partition { |c| c[:breaking] }

          if breaking.any?
            lines << "### Breaking Changes"
            lines << ""
            breaking.each { |c| lines << "- #{c[:label]}" }
            lines << ""
          end

          if non_breaking.any?
            lines << "### Changes"
            lines << ""
            non_breaking.each { |c| lines << "- #{c[:label]}" }
            lines << ""
          end
        end

        lines << ""
        lines.join("\n")
      end

      # @api private
      def self.version_section(version, tagged_at, old_domain, new_domain)
        lines = ["## #{version}"]
        lines << "_Tagged: #{tagged_at}_" if tagged_at
        lines << ""

        changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
        classified = BreakingClassifier.classify(changes)

        if classified.empty?
          lines << "No changes."
          lines << ""
          return lines
        end

        breaking, non_breaking = classified.partition { |c| c[:breaking] }

        if breaking.any?
          lines << "### Breaking Changes"
          lines << ""
          breaking.each { |c| lines << "- #{c[:label]}" }
          lines << ""
        end

        if non_breaking.any?
          lines << "### Changes"
          lines << ""
          non_breaking.each { |c| lines << "- #{c[:label]}" }
          lines << ""
        end

        lines
      end

      private_class_method :version_section
    end
  end
end
