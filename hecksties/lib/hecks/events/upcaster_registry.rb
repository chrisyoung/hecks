# = Hecks::Events::UpcasterRegistry
#
# Registry mapping [event_type, version] pairs to transform procs.
# Each transform takes an event data hash at one version and returns
# the data hash at the next version. Used by UpcasterEngine to chain
# transforms from a stored version to the current schema version.
#
#   registry = UpcasterRegistry.new
#   registry.register("CreatedPizza", from: 1, to: 2) do |data|
#     data.merge("description" => data.delete("style") || "")
#   end
#   registry.lookup("CreatedPizza", 1)
#   # => { to: 2, transform: #<Proc> }
#
module Hecks
  module Events
    class UpcasterRegistry
      def initialize
        @transforms = {}
      end

      # Register a transform from one version to the next.
      #
      # @param event_type [String] the event type name (e.g. "CreatedPizza")
      # @param from [Integer] source schema version
      # @param to [Integer] target schema version
      # @yield [data] transform block receiving the event data hash
      # @yieldreturn [Hash] the transformed data hash
      # @return [void]
      def register(event_type, from:, to:, &transform)
        key = [event_type.to_s, from]
        @transforms[key] = { to: to, transform: transform }
      end

      # Look up a transform for the given event type and version.
      #
      # @param event_type [String] the event type name
      # @param version [Integer] the source schema version
      # @return [Hash, nil] { to:, transform: } or nil if no transform registered
      def lookup(event_type, version)
        @transforms[[event_type.to_s, version]]
      end

      # Check if any transforms are registered for the given event type.
      #
      # @param event_type [String] the event type name
      # @return [Boolean]
      def any_for?(event_type)
        @transforms.keys.any? { |type, _| type == event_type.to_s }
      end

      # Returns the number of registered transforms.
      #
      # @return [Integer]
      def size
        @transforms.size
      end
    end
  end
end
