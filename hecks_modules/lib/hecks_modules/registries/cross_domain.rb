# Hecks::CrossDomainMethods
#
# Cross-domain queries, views, and shared event bus.
# Extracted from the Hecks module.
#
module Hecks
  module CrossDomainMethods
    extend ModuleDSL

    lazy_registry :cross_domain_queries
    lazy_registry :cross_domain_views

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
      cross_domain_queries[name] = CrossDomainQuery.new(name, &block)
    end

    def query(name, **params)
      q = cross_domain_queries[name]
      raise Error, "Unknown cross-domain query: #{name}" unless q
      q.call(**params)
    end

    def cross_domain_view(name, &block)
      view = CrossDomainView.new(name, &block)
      cross_domain_views[name] = view
      view.subscribe(@shared_event_bus) if @shared_event_bus
      view
    end
  end
end
