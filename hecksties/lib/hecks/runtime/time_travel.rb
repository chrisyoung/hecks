# Hecks::Runtime::TimeTravel
#
# Mixin for Runtime that enables event replay to reconstruct aggregate
# state at a past point in time or version. Works with the in-memory
# EventStore to filter events, then applies them sequentially to build
# the aggregate.
#
# == Usage
#
#   app.as_of(1.hour.ago).find("Pizza", pizza_id)
#   app.at_version("Pizza", pizza_id, version: 3)
#
module Hecks
  class Runtime
    module TimeTravel
      # Returns an AsOfProxy scoped to the given timestamp. The proxy
      # delegates find calls to reconstitute_at.
      #
      # @param timestamp [Time] the point in time to replay to
      # @return [Hecks::Runtime::AsOfProxy] a proxy that answers find queries
      def as_of(timestamp)
        AsOfProxy.new(self, timestamp)
      end

      # Reconstitutes an aggregate by replaying events up to the given version.
      #
      # @param aggregate_type [String] the aggregate name (e.g. "Pizza")
      # @param id [String] the aggregate instance ID
      # @param version [Integer] the version to replay up to
      # @return [Object, nil] the reconstructed aggregate, or nil if no events
      def at_version(aggregate_type, id, version:)
        stream_id = "#{aggregate_type}-#{id}"
        records = event_store.read_stream_to_version(stream_id, version: version)
        reconstitute_from_records(aggregate_type, id, records)
      end

      # Reconstitutes an aggregate by replaying events up to the given timestamp.
      #
      # @param aggregate_type [String] the aggregate name (e.g. "Pizza")
      # @param id [String] the aggregate instance ID
      # @param timestamp [Time] the cutoff time
      # @return [Object, nil] the reconstructed aggregate, or nil if no events
      def reconstitute_at(aggregate_type, id, timestamp:)
        stream_id = "#{aggregate_type}-#{id}"
        records = event_store.read_stream_until(stream_id, timestamp: timestamp)
        reconstitute_from_records(aggregate_type, id, records)
      end

      # Reconstitutes an aggregate by replaying events up to a version number.
      # Alias that delegates to at_version for naming symmetry.
      #
      # @param aggregate_type [String] the aggregate name (e.g. "Pizza")
      # @param id [String] the aggregate instance ID
      # @param version [Integer] the version to replay up to
      # @return [Object, nil] the reconstructed aggregate, or nil if no events
      def reconstitute_at_version(aggregate_type, id, version:)
        at_version(aggregate_type, id, version: version)
      end

      private

      # Builds an aggregate from a sequence of event records by extracting
      # attribute values from each event and applying them cumulatively.
      #
      # @param aggregate_type [String] the aggregate name
      # @param id [String] the aggregate ID
      # @param records [Array<Hash>] the event records to replay
      # @return [Object, nil] the reconstructed aggregate, or nil if no records
      def reconstitute_from_records(aggregate_type, id, records)
        return nil if records.empty?

        agg_class = resolve_aggregate_class(aggregate_type)
        return nil unless agg_class

        attr_names = Persistence::RepositoryMethods.attr_names(agg_class).map(&:to_sym)
        attrs = {}

        records.each do |record|
          event = record[:event]
          attr_names.each do |name|
            attrs[name] = event.send(name) if event.respond_to?(name)
          end
        end

        agg_class.new(id: id, **attrs)
      end

      # Resolves the Ruby class for a given aggregate type name.
      #
      # @param aggregate_type [String] the aggregate name (e.g. "Pizza")
      # @return [Class, nil] the aggregate class, or nil if not found
      def resolve_aggregate_class(aggregate_type)
        @mod.const_get(aggregate_type)
      rescue NameError
        nil
      end
    end
  end
end
