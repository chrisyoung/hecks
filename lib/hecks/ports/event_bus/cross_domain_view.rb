# Hecks::CrossDomainView
#
# An event-driven read model that projects events from multiple bounded
# contexts into a single in-memory state. Subscribes to the shared event
# bus and applies projection functions as events arrive.
#
#   view = Hecks.cross_domain_view "RiskDashboard" do
#     project("RegisteredModel") { |e, s| s.merge(total: (s[:total] || 0) + 1) }
#     project("ReportedIncident") { |e, s| s.merge(incidents: (s[:incidents] || 0) + 1) }
#   end
#
#   view.state  # => { total: 5, incidents: 2 }
#
module Hecks
  class CrossDomainView
    attr_reader :name, :state

    def initialize(name, &block)
      @name = name
      @projections = {}
      @state = {}
      instance_eval(&block) if block
    end

    def project(event_name, &block)
      @projections[event_name] = block
    end

    def subscribe(event_bus)
      return unless event_bus
      @projections.each_key do |event_name|
        event_bus.subscribe(event_name) do |event|
          apply(event)
        end
      end
    end

    def apply(event)
      event_name = event.class.name.split("::").last
      projection = @projections[event_name]
      @state = projection.call(event, @state) if projection
    end

    def reset
      @state = {}
    end
  end
end
