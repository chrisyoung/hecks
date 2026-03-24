# Hecks::DomainModel::Behavior::EventSubscriber
#
# Intermediate representation of a DSL-defined event subscriber -- an
# arbitrary code block that fires when a named event is published.
# Unlike reactive policies (which must trigger a command), subscribers
# can run any code: logging, notifications, cross-aggregate side effects.
#
# Part of the DomainModel IR layer. Built by AggregateBuilder#on_event
# and consumed by SubscriberGenerator to produce subscriber classes.
#
#   sub = EventSubscriber.new(
#     name: "OnCreatedPizza",
#     event_name: "CreatedPizza",
#     block: proc { |event| puts event.name },
#     async: false
#   )
#
module Hecks
  module DomainModel
    module Behavior
    class EventSubscriber
      attr_reader :name, :event_name, :block, :async

      def initialize(name:, event_name:, block:, async: false)
        @name = name
        @event_name = event_name
        @block = block
        @async = async
      end
    end
    end
  end
end
