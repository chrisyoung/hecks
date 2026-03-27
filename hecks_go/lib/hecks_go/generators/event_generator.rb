# HecksGo::EventGenerator
#
# Generates a Go struct for a domain event. Events are immutable value
# types with an OccurredAt timestamp and an EventName() method.
#
module HecksGo
  class EventGenerator
    include GoUtils

    def initialize(event, aggregate:, package:)
      @event = event
      @aggregate = aggregate
      @package = package
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""
      lines << "import \"time\""
      lines << ""

      lines << "type #{@event.name} struct {"
      lines << "\tAggregateID string    `json:\"aggregate_id\"`"
      @event.attributes.each do |attr|
        field = GoUtils.pascal_case(attr.name)
        go_t = GoUtils.go_type(attr)
        tag = GoUtils.json_tag(attr.name)
        lines << "\t#{field} #{go_t} `json:\"#{tag}\"`"
      end
      # Add aggregate attrs that aren't already in the event
      agg_attrs = @aggregate.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
      agg_attrs.each do |attr|
        next if @event.attributes.any? { |ea| ea.name == attr.name }
        field = GoUtils.pascal_case(attr.name)
        go_t = GoUtils.go_type(attr)
        tag = GoUtils.json_tag(attr.name)
        lines << "\t#{field} #{go_t} `json:\"#{tag}\"`"
      end
      lines << "\tOccurredAt time.Time `json:\"occurred_at\"`"
      lines << "}"
      lines << ""

      lines << "func (e #{@event.name}) EventName() string { return \"#{@event.name}\" }"
      lines << ""
      lines << "func (e #{@event.name}) GetOccurredAt() time.Time { return e.OccurredAt }"

      lines.join("\n") + "\n"
    end
  end
end
