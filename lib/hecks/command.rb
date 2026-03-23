# Hecks::Command
#
# Mixin for generated command classes. Provides repository and event bus
# wiring so commands are self-contained and callable without external setup.
#
#   class CreatePizza
#     include Hecks::Command
#     # ...
#     def call
#       pizza = Pizza.new(name: name)
#       repository.save(pizza)
#       emit Events::CreatedPizza.new(name: name)
#       pizza
#     end
#   end
#
#   CreatePizza.call(name: "Margherita")
#
module Hecks
  module Command
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      attr_accessor :repository, :event_bus, :handler, :event_recorder, :aggregate_type, :command_bus

      def call(**attrs)
        cmd = new(**attrs)
        if command_bus && !command_bus.middleware.empty?
          command_bus.dispatch_with_command(cmd) { cmd.call }
        else
          cmd.call
        end
      end
    end

    private

    def repository
      self.class.repository
    end

    def event_bus
      self.class.event_bus
    end

    def run_handler
      self.class.handler&.call(self)
    end

    def emit(event)
      event_bus&.publish(event)
      event
    end

    def record_event(aggregate_id, event)
      recorder = self.class.event_recorder
      agg_type = self.class.aggregate_type
      recorder.record(agg_type, aggregate_id, event) if recorder
    end
  end
end
