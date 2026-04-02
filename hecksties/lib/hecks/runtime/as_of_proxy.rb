# Hecks::Runtime::AsOfProxy
#
# A lightweight proxy returned by +Runtime#as_of(timestamp)+. Scopes
# all +find+ calls to reconstitute aggregate state as of the given
# point in time by replaying events from the EventStore.
#
# == Usage
#
#   snapshot = app.as_of(1.hour.ago)
#   pizza = snapshot.find("Pizza", pizza_id)
#   pizza.name  # => the name at that point in time
#
module Hecks
  class Runtime
    class AsOfProxy
      # Creates a new proxy scoped to a timestamp.
      #
      # @param runtime [Hecks::Runtime] the runtime to query against
      # @param timestamp [Time] the point in time to replay events to
      def initialize(runtime, timestamp)
        @runtime = runtime
        @timestamp = timestamp
      end

      # Reconstitutes an aggregate as of the scoped timestamp.
      #
      # @param aggregate_type [String] the aggregate name (e.g. "Pizza")
      # @param id [String] the aggregate instance ID
      # @return [Object, nil] the reconstructed aggregate, or nil if no events
      def find(aggregate_type, id)
        @runtime.reconstitute_at(aggregate_type, id, timestamp: @timestamp)
      end

      # Returns a readable summary of this proxy.
      #
      # @return [String]
      def inspect
        "#<Hecks::Runtime::AsOfProxy as_of=#{@timestamp.iso8601}>"
      end
    end
  end
end
