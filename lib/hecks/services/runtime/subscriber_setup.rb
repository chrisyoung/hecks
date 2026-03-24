# Hecks::Services::Runtime::SubscriberSetup
#
# Mixin that wires DSL-defined event subscribers to the event bus at
# boot time. Sync subscribers fire inline; async subscribers are passed
# to the registered async handler.
#
#   class Runtime
#     include SubscriberSetup
#   end
#
module Hecks
  module Services
    class Runtime
      module SubscriberSetup
        private

        def setup_subscribers
          @domain.aggregates.each do |agg|
            agg.subscribers.each do |sub|
              safe_name = Hecks::Utils.sanitize_constant(agg.name)
              sub_class = @mod.const_get(safe_name)::Subscribers.const_get(sub.name)
              handler = sub_class.new

              @event_bus.subscribe(sub.event_name) do |event|
                if sub.async && @async_handler
                  @async_handler.call("#{@mod_name}::#{safe_name}::Subscribers::#{sub.name}", event)
                else
                  handler.call(event)
                end
              end
            end
          end
        end
      end
    end
  end
end
