# Hecks::FilteredEventBus
#
# Decorator around EventBus that enforces cross-domain event directionality.
# Tags outgoing events with the publishing domain's gem_name, and filters
# incoming events so only declared sources are received. When allowed_sources
# is nil, all events pass through (open bus / backward-compatible mode).
#
#   bus = FilteredEventBus.new(
#     inner: shared_bus,
#     domain_gem_name: "orders_domain",
#     allowed_sources: ["inventory_domain"]
#   )
#   bus.publish(event)     # tags event with source "orders_domain"
#   bus.subscribe("Foo") { |e| ... }  # only fires for allowed sources
#
module Hecks
  class FilteredEventBus
    attr_reader :events

    def initialize(inner:, domain_gem_name:, allowed_sources: nil)
      @inner = inner
      @domain_gem_name = domain_gem_name
      @allowed_sources = allowed_sources&.map(&:to_s)
    end

    def publish(event)
      event.instance_variable_set(:@_source_domain, @domain_gem_name)
      @inner.publish(event)
    end

    def subscribe(event_name, &handler)
      filtered = wrap_handler(handler)
      @inner.subscribe(event_name, &filtered)
    end

    def on_any(&handler)
      filtered = wrap_handler(handler)
      @inner.on_any(&filtered)
    end

    def events
      @inner.events
    end

    def clear
      @inner.clear
    end

    private

    def wrap_handler(handler)
      return handler unless @allowed_sources

      sources = @allowed_sources
      ->(event) {
        source = event.instance_variable_get(:@_source_domain)
        handler.call(event) if source.nil? || sources.include?(source)
      }
    end
  end
end
