# = Hecks::Events::UpcasterEngine
#
# Applies upcaster transforms from a stored schema version to the
# current version. Chains transforms sequentially: v1 -> v2 -> v3.
# Returns the original data unchanged if no transforms are needed.
#
#   engine = UpcasterEngine.new(registry)
#   engine.upcast("CreatedPizza", data: { "name" => "M" }, from_version: 1, to_version: 3)
#   # => { "name" => "M", "description" => "", "category" => "classic" }
#
module Hecks
  module Events
    class UpcasterEngine
      # @param registry [UpcasterRegistry] the registry of transforms
      def initialize(registry)
        @registry = registry
      end

      # Apply all transforms needed to bring event data from one version to another.
      #
      # @param event_type [String] the event type name
      # @param data [Hash] the stored event data hash
      # @param from_version [Integer] the version the data was stored at
      # @param to_version [Integer] the target version to upcast to
      # @return [Hash] the upcasted data hash
      # @raise [Hecks::Error] if a transform is missing for an intermediate version
      def upcast(event_type, data:, from_version:, to_version:)
        return data if from_version >= to_version

        current_data = data.dup
        current_version = from_version

        while current_version < to_version
          entry = @registry.lookup(event_type, current_version)
          unless entry
            raise Hecks::Error,
              "Missing upcaster for #{event_type} from version #{current_version}"
          end
          current_data = entry[:transform].call(current_data)
          current_version = entry[:to]
        end

        current_data
      end
    end
  end
end
