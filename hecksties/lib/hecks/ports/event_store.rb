# Hecks::EventStore
#
# In-memory event store that records domain events per aggregate stream.
# Each event is stored with a stream ID, version number, and occurred_at
# timestamp. Supports time-travel queries for replaying events up to a
# point in time or a specific version.
#
# == Usage
#
#   store = Hecks::EventStore.new
#   store.append("Pizza-42", event)
#   store.read_stream("Pizza-42")           # => all events
#   store.read_stream_until("Pizza-42", timestamp: cutoff)
#   store.read_stream_to_version("Pizza-42", version: 3)
#
module Hecks
  class EventStore
    # @return [Array<Hash>] all stored event records across all streams
    attr_reader :records

    # Initializes an empty event store.
    def initialize
      @records = []
      @stream_versions = Hash.new(0)
    end

    # Appends an event to the given stream. Assigns the next version number
    # for that stream and captures the event's occurred_at timestamp.
    #
    # @param stream_id [String] the stream identifier (e.g. "Pizza-42")
    # @param event [Object] domain event with +.occurred_at+ and +.class.name+
    # @return [Hash] the stored event record
    def append(stream_id, event)
      @stream_versions[stream_id] += 1
      record = {
        stream_id: stream_id,
        version: @stream_versions[stream_id],
        event_type: Hecks::Utils.const_short_name(event),
        event: event,
        occurred_at: event.occurred_at
      }
      @records << record
      record
    end

    # Returns all events in a stream ordered by version.
    #
    # @param stream_id [String] the stream identifier
    # @return [Array<Hash>] event records ordered by version
    def read_stream(stream_id)
      @records
        .select { |r| r[:stream_id] == stream_id }
        .sort_by { |r| r[:version] }
    end

    # Returns events in a stream that occurred at or before the given timestamp.
    #
    # @param stream_id [String] the stream identifier
    # @param timestamp [Time] the cutoff time (inclusive)
    # @return [Array<Hash>] filtered event records ordered by version
    def read_stream_until(stream_id, timestamp:)
      read_stream(stream_id).select { |r| r[:occurred_at] <= timestamp }
    end

    # Returns events in a stream up to and including the given version.
    #
    # @param stream_id [String] the stream identifier
    # @param version [Integer] the maximum version number (inclusive)
    # @return [Array<Hash>] filtered event records ordered by version
    def read_stream_to_version(stream_id, version:)
      read_stream(stream_id).select { |r| r[:version] <= version }
    end

    # Returns the current version (highest version number) for a stream.
    #
    # @param stream_id [String] the stream identifier
    # @return [Integer] the current version, or 0 if no events exist
    def stream_version(stream_id)
      @stream_versions[stream_id]
    end

    # Removes all stored events. Does not affect external listeners.
    #
    # @return [void]
    def clear
      @records.clear
      @stream_versions.clear
    end
  end
end
