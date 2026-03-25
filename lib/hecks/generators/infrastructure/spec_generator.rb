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
require_relative "spec_helpers"
require_relative "spec_generator/aggregate_spec"
require_relative "spec_generator/value_object_spec"
require_relative "spec_generator/command_spec"
require_relative "spec_generator/event_spec"
require_relative "spec_generator/entity_spec"

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

      def initialize(domain)
        @domain = domain
      end

      def generate_spec_helper
        <<~RUBY
          require "hecks"
          require "#{@domain.gem_name}"

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

      def mod_name
        @domain.module_name + "Domain"
      end
    end
    end
  end
end
