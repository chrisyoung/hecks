# Hecks::DomainVersioning::ChangelogGenerator
#
# Loads version snapshots from db/hecks_versions/, diffs consecutive
# pairs, and classifies each change as breaking or non-breaking.
# Returns structured data ready for rendering.
#
#   sections = ChangelogGenerator.call(base_dir: Dir.pwd)
#   sections.each do |section|
#     puts "#{section[:version]} (#{section[:tagged_at]})"
#     section[:breaking].each { |c| puts "  BREAKING: #{c[:label]}" }
#     section[:additions].each { |c| puts "  Added: #{c[:label]}" }
#   end
#
module Hecks
  module DomainVersioning
    module ChangelogGenerator
      # Generate changelog sections from all tagged version snapshots.
      #
      # Each section represents one version and contains classified changes
      # relative to its predecessor. The first version gets an "Initial release"
      # marker.
      #
      # @param base_dir [String] project root directory
      # @return [Array<Hash>] newest-first, each with :version, :tagged_at,
      #   :breaking, :additions keys
      def self.call(base_dir: Dir.pwd)
        entries = DomainVersioning.log(base_dir: base_dir)
        return [] if entries.empty?

        # entries are newest-first; we need consecutive pairs (newer, older)
        entries.each_with_index.map do |entry, i|
          older = entries[i + 1]
          build_section(entry, older)
        end
      end

      # Build a single changelog section by diffing two version snapshots.
      #
      # @param entry [Hash] the newer version entry
      # @param older [Hash, nil] the older version entry (nil for first)
      # @return [Hash] with :version, :tagged_at, :breaking, :additions
      def self.build_section(entry, older)
        unless older
          return {
            version: entry[:version],
            tagged_at: entry[:tagged_at],
            breaking: [],
            additions: [],
            initial: true
          }
        end

        old_domain = load_snapshot(older[:path])
        new_domain = load_snapshot(entry[:path])

        unless old_domain && new_domain
          return {
            version: entry[:version],
            tagged_at: entry[:tagged_at],
            breaking: [],
            additions: [],
            initial: false
          }
        end

        changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
        classified = BreakingClassifier.classify(changes)

        {
          version: entry[:version],
          tagged_at: entry[:tagged_at],
          breaking: classified.select { |c| c[:breaking] },
          additions: classified.reject { |c| c[:breaking] },
          initial: false
        }
      end

      # Load a domain from a snapshot file.
      #
      # @param path [String] snapshot file path
      # @return [Hecks::DomainModel::Domain, nil]
      def self.load_snapshot(path)
        return nil unless File.exist?(path)
        Kernel.load(path)
        Hecks.last_domain
      end
    end
  end
end
