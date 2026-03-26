require_relative "spec_helpers"
require_relative "spec_generator/aggregate_spec"
require_relative "spec_generator/value_object_spec"
require_relative "spec_generator/command_spec"
require_relative "spec_generator/event_spec"
require_relative "spec_generator/entity_spec"

# Hecks::Generators::Infrastructure::SpecGenerator
#
# Generates behavioral RSpec specs from domain IR. Produces specs that
# describe what aggregates, commands, events, and value objects *do*,
# not just that they exist. Each concept has its own mixin. Part of
# Generators::Infrastructure, consumed by DomainGemGenerator::SpecWriter.
#
#   gen = SpecGenerator.new(domain)
#   gen.generate_aggregate_spec(agg)
#   gen.generate_command_spec(cmd, agg)
#   gen.generate_event_spec(evt, agg)
#   gen.generate_value_object_spec(vo, agg)
#

module Hecks
  module Generators
    module Infrastructure
    class SpecGenerator
      include SpecHelpers
      include AggregateSpec
      include ValueObjectSpec
      include CommandSpec
      include EventSpec
      include EntitySpec

      # Creates a new SpecGenerator for a domain.
      #
      # @param domain [Hecks::DomainModel::Structure::Domain] the parsed domain IR
      def initialize(domain)
        @domain = domain
      end

      # Generates the +spec/spec_helper.rb+ content for the domain gem.
      #
      # Includes:
      # - +require "hecks"+ and +require "<gem_name>"+
      # - +require "date"+ when any aggregate uses +Date+ or +DateTime+ attributes
      # - Standard RSpec configuration (chain clauses, partial double verification,
      #   focus filtering, random ordering)
      #
      # @return [String] the complete Ruby source for +spec/spec_helper.rb+
      def generate_spec_helper
        needs_date = @domain.aggregates.any? { |a|
          a.attributes.any? { |attr| %w[Date DateTime].include?(attr.type.to_s) }
        }
        <<~RUBY
          require "hecks"
          #{"require \"date\"\n" if needs_date}require "#{@domain.gem_name}"

          RSpec.configure do |config|
            config.expect_with :rspec do |expectations|
              expectations.include_chain_clauses_in_custom_matcher_descriptions = true
            end

            config.mock_with :rspec do |mocks|
              mocks.verify_partial_doubles = true
            end

            config.filter_run_when_matching :focus
            config.order = :random
          end
        RUBY
      end

      private

      # Returns the fully qualified domain module name used in spec expectations
      # (e.g. +"PizzasDomain"+).
      #
      # @return [String] the domain module name with "Domain" suffix
      def mod_name
        @domain.module_name + "Domain"
      end
    end
    end
  end
end
