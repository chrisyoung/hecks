# = Hecks::TestHelper::PropertyTesting::AggregateGenerator
#
# Generates N random valid attribute hashes for an aggregate root. Uses
# TypeGenerators to produce type-appropriate values for each attribute.
# Useful for fuzz testing, bulk creation tests, and property assertions.
#
#   domain = Hecks.domain("Pizzas") { aggregate("Pizza") { attribute :name, String } }
#   gen = AggregateGenerator.new(domain.aggregates.first, seed: 42)
#   gen.generate(5)  # => [{ name: "prop_abc" }, { name: "prop_xyz" }, ...]
#
module Hecks
  module TestHelper
    module PropertyTesting
      class AggregateGenerator
        attr_reader :aggregate, :type_generators

        # @param aggregate [Hecks::DomainModel::Structure::Aggregate] the aggregate IR
        # @param seed [Integer, nil] random seed for reproducibility
        def initialize(aggregate, seed: nil)
          @aggregate = aggregate
          @type_generators = TypeGenerators.new(seed: seed)
        end

        # @return [Integer] the seed used by the underlying type generator
        def seed
          @type_generators.seed
        end

        # Generate N random attribute hashes for the aggregate.
        #
        # @param count [Integer] number of hashes to generate
        # @return [Array<Hash{Symbol => Object}>] random attribute hashes
        def generate(count)
          Array.new(count) { generate_one }
        end

        # Generate a single random attribute hash.
        #
        # @return [Hash{Symbol => Object}] a single random attribute hash
        def generate_one
          result = {}
          @aggregate.attributes.each do |attr|
            result[attr.name] = @type_generators.generate_for_attribute(attr)
          end
          result
        end

        # Generate attribute hashes for a specific command on this aggregate.
        #
        # @param command_name [String] the command name
        # @param count [Integer] number of hashes to generate
        # @return [Array<Hash{Symbol => Object}>] random command attribute hashes
        def generate_for_command(command_name, count)
          cmd = @aggregate.commands.find { |c| c.name == command_name }
          raise ArgumentError, "Unknown command: #{command_name}" unless cmd

          Array.new(count) { build_command_hash(cmd) }
        end

        private

        def build_command_hash(command)
          result = {}
          command.attributes.each do |attr|
            result[attr.name] = @type_generators.generate_for_attribute(attr)
          end
          result
        end
      end
    end
  end
end
