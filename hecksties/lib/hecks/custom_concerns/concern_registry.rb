# Hecks::CustomConcerns::ConcernRegistry
#
# Stores custom concern definitions registered via `Hecks.concern`.
# Provides lookup by name and enumeration of all registered concerns.
#
#   registry = ConcernRegistry.new
#   registry.register(concern)
#   registry.find(:hipaa_compliance) # => Concern
#   registry.all                     # => [Concern, ...]
#   registry.names                   # => [:hipaa_compliance, ...]
#
module Hecks
  module CustomConcerns
    class ConcernRegistry
      def initialize
        @concerns = {}
      end

      # Register a concern. Overwrites any existing concern with the same name.
      #
      # @param concern [Concern] the concern to register
      # @return [void]
      def register(concern)
        @concerns[concern.name] = concern
      end

      # Look up a concern by name.
      #
      # @param name [Symbol] the concern name
      # @return [Concern, nil]
      def find(name)
        @concerns[name.to_sym]
      end

      # All registered concern names.
      #
      # @return [Array<Symbol>]
      def names
        @concerns.keys
      end

      # All registered concerns.
      #
      # @return [Array<Concern>]
      def all
        @concerns.values
      end

      # True if a concern with this name is registered.
      #
      # @param name [Symbol] the concern name
      # @return [Boolean]
      def registered?(name)
        @concerns.key?(name.to_sym)
      end

      # Remove all registered concerns (useful for test cleanup).
      #
      # @return [void]
      def clear!
        @concerns.clear
      end
    end
  end
end
