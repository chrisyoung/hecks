module Hecks
  module PropertyTesting

    # Hecks::PropertyTesting::AggregateGenerator
    #
    # Generates random valid attribute hashes for a specific aggregate's
    # commands. Uses TypeGenerator to produce values matching each
    # attribute's declared type.
    #
    #   gen = AggregateGenerator.new(aggregate, seed: 42)
    #   gen.command_attrs("CreatePizza")  # => { name: "dxpk", description: "mwqr" }
    #   gen.samples("CreatePizza", count: 10)  # => [{ ... }, ...]
    #
    class AggregateGenerator
      # @param aggregate [Hecks::DomainModel::Structure::Aggregate] the aggregate
      # @param seed [Integer] random seed for reproducibility
      def initialize(aggregate, seed: Random.new_seed)
        @aggregate = aggregate
        @type_gen = TypeGenerator.new(seed: seed)
      end

      # Generate a random valid attribute hash for a command.
      #
      # @param command_name [String] the command name
      # @return [Hash] attribute name-value pairs
      def command_attrs(command_name)
        cmd = @aggregate.commands.find { |c| c.name == command_name.to_s }
        return {} unless cmd

        cmd.attributes.each_with_object({}) do |attr, hash|
          hash[attr.name] = @type_gen.for_type(attr.type)
        end
      end

      # Generate multiple sample attribute hashes for a command.
      #
      # @param command_name [String] the command name
      # @param count [Integer] number of samples to generate
      # @return [Array<Hash>] array of attribute hashes
      def samples(command_name, count: 10)
        count.times.map { command_attrs(command_name) }
      end

      # Generate a random valid attribute hash for the aggregate root.
      #
      # @return [Hash] attribute name-value pairs
      def root_attrs
        @aggregate.attributes.each_with_object({}) do |attr, hash|
          hash[attr.name] = @type_gen.for_type(attr.type)
        end
      end
    end
  end
end
