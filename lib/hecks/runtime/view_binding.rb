# Hecks::ViewBinding
#
# Wires read model projections to the event bus at runtime. For each
# read model, creates a module under the domain namespace with a .current
# method that returns the projected state hash, and subscribes projection
# procs to the event bus so state is updated as events are published.
#
#   ViewBinding.bind(view, event_bus, domain_mod)
#   # After events are published:
#   PizzasDomain::OrderSummary.current  # => { total_orders: 5 }
#
module Hecks
  class ViewBinding
    def self.bind(view, event_bus, mod)
      state = {}
      mutex = Mutex.new

      view_mod = Module.new do
        define_singleton_method(:current) { mutex.synchronize { state.dup } }
      end

      mod.const_set(Hecks::Utils.sanitize_constant(view.name), view_mod)

      view.projections.each do |event_name, projection|
        event_bus.subscribe(event_name) do |event|
          mutex.synchronize do
            state = projection.call(event, state)
          end
        end
      end
    end
  end
end
