# Hecks::CrossDomainMethods
#
# Cross-domain queries, views, and shared event bus.
# Extracted from the Hecks module.
#
module Hecks
  module CrossDomainMethods
    def event_bus
      @shared_event_bus
    end

    def queue
      @queue ||= Queue::MemoryQueue.new
    end

    def queue=(q)
      @queue = q
    end

    def cross_domain_query(name, &block)
      require "hecks/ports/queries/cross_domain_query"
      @cross_domain_queries[name] = CrossDomainQuery.new(name, &block)
    end

    def query(name, **params)
      q = @cross_domain_queries[name]
      raise Error, "Unknown cross-domain query: #{name}" unless q
      q.call(**params)
    end

    def cross_domain_queries
      @cross_domain_queries
    end

    def cross_domain_view(name, &block)
      require "hecks/ports/event_bus/cross_domain_view"
      view = CrossDomainView.new(name, &block)
      @cross_domain_views[name] = view
      view.subscribe(@shared_event_bus) if @shared_event_bus
      view
    end

    def cross_domain_views
      @cross_domain_views
    end
  end
end
