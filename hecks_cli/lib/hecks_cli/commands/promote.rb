# Hecks::CLI::Domain#promote
#
# Extracts an aggregate from the current domain into its own standalone
# domain file. The aggregate is removed from the source domain and a new
# domain file is written for it.
#
#   hecks domain promote Comments
#   # => Wrote comment_domain.rb (3 attributes, 2 commands)
#   # => Comments removed from Blog
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      include HecksTemplating::NamingHelpers
      desc "promote AGGREGATE", "Extract an aggregate into its own domain"
      # Promotes an aggregate from the current domain into a standalone domain.
      #
      # Loads the domain from hecks_domain.rb, extracts the named aggregate,
      # writes a new domain file for it, and re-saves the original domain
      # without the promoted aggregate.
      #
      # @param aggregate_name [String] the aggregate to promote
      # @return [void]
      def promote(aggregate_name)
        domain = resolve_domain_option
        return unless domain

        agg_name = domain_constant_name(aggregate_name)
        agg = domain.aggregates.find { |a| a.name == agg_name }
        unless agg
          say "No aggregate named #{agg_name} in #{domain.name}", :red
          say "Available: #{domain.aggregates.map(&:name).join(', ')}"
          return
        end

        # Build a standalone domain for the promoted aggregate
        new_domain = DomainModel::Structure::Domain.new(
          name: agg_name, aggregates: [agg], custom_verbs: []
        )
        new_file = "#{domain_snake_name(agg_name)}_domain.rb"
        File.write(new_file, DslSerializer.new(new_domain).serialize)
        say "Wrote #{new_file} (#{agg.attributes.size} attributes, #{agg.commands.size} commands)", :green

        # Re-save the original domain without the promoted aggregate
        remaining = domain.aggregates.reject { |a| a.name == agg_name }
        updated = DomainModel::Structure::Domain.new(
          name: domain.name, aggregates: remaining, custom_verbs: domain.custom_verbs
        )
        source_file = find_domain_file || "hecks_domain.rb"
        File.write(source_file, DslSerializer.new(updated).serialize)
        say "#{agg_name} removed from #{domain.name} (#{source_file} updated)", :green
      end
    end
  end
end
