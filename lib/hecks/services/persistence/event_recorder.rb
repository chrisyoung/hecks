# Hecks::Persistence::EventRecorder
#
# Records domain events to a SQL events table. Enabled via
# `adapter :sql, event_sourced: true` in Hecks.configure.
# Provides aggregate history and event stream queries.
#
#   recorder = EventRecorder.new(db)
#   recorder.record("Pizza", pizza.id, event)
#   recorder.history("Pizza", pizza.id)  # => [event_hash, ...]
#
require "json"

module Hecks
  module Persistence
    class EventRecorder
        def initialize(db)
          @db = db
          ensure_table
        end

        def record(aggregate_type, aggregate_id, event)
          stream_id = "#{aggregate_type}-#{aggregate_id}"
          version = next_version(stream_id)

          @db[:domain_events].insert(
            stream_id: stream_id,
            event_type: event.class.name.split("::").last,
            data: serialize_event(event),
            occurred_at: event.occurred_at.iso8601,
            version: version
          )
        end

        def history(aggregate_type, aggregate_id)
          stream_id = "#{aggregate_type}-#{aggregate_id}"
          @db[:domain_events]
            .where(stream_id: stream_id)
            .order(:version)
            .all
            .map { |row| deserialize_row(row) }
        end

        def all_events
          @db[:domain_events].order(:id).all.map { |row| deserialize_row(row) }
        end

        private

        def next_version(stream_id)
          last = @db[:domain_events]
            .where(stream_id: stream_id)
            .max(:version)
          (last || 0) + 1
        end

        def serialize_event(event)
          attrs = {}
          event.class.instance_method(:initialize).parameters.each do |_, name|
            next unless name && name != :occurred_at
            attrs[name] = event.send(name) if event.respond_to?(name)
          end
          JSON.generate(attrs)
        end

        def deserialize_row(row)
          {
            stream_id: row[:stream_id],
            event_type: row[:event_type],
            data: JSON.parse(row[:data] || "{}"),
            occurred_at: row[:occurred_at],
            version: row[:version]
          }
        end

        def ensure_table
          return if @db.table_exists?(:domain_events)

          @db.create_table(:domain_events) do
            primary_key :id
            String :stream_id, null: false
            String :event_type, null: false
            String :data, text: true
            String :occurred_at
            Integer :version
            index :stream_id
          end
        end
      end
  end
end
