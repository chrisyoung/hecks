# Hecks::Command
#
# Mixin for generated command classes. Orchestrates the full command lifecycle:
# run handler, execute call, emit event, record event. The generated call
# method only contains domain logic (build and save the aggregate).
#
#   class CreatePizza
#     include Hecks::Command
#     emits "CreatedPizza"
#
#     def call
#       save Pizza.new(name: name, created_at: Time.now, updated_at: Time.now)
#     end
#   end
#
#   cmd = CreatePizza.call(name: "Margherita")
#   cmd.aggregate  # => #<Pizza>
#   cmd.event      # => #<CreatedPizza>
#
module Hecks
  module Command
    def self.included(base)
      base.extend(ClassMethods)
      base.attr_reader :aggregate, :event
    end

    module ClassMethods
      attr_accessor :repository, :event_bus, :handler, :event_recorder,
                    :aggregate_type, :command_bus

      def emits(event_name)
        @event_name = event_name
      end

      def event_name
        @event_name
      end

      def event_class
        agg_module = name.split("::")[0..-3].join("::")
        Object.const_get("#{agg_module}::Events::#{@event_name}")
      end

      def call(**attrs)
        cmd = new(**attrs)
        cmd.send(:run_handler)
        if command_bus && !command_bus.middleware.empty?
          command_bus.dispatch_with_command(cmd) { cmd.call }
        else
          cmd.call
        end
        cmd.send(:emit_event)
        cmd.send(:record_event_for_aggregate)
        cmd
      end
    end

    private

    def repository
      self.class.repository
    end

    def run_handler
      self.class.handler&.call(self)
    end

    def save(agg)
      @aggregate = agg
      repository.save(agg)
      agg
    end

    def emit_event
      event_class = self.class.event_class
      event_params = event_class.instance_method(:initialize).parameters.map { |_, n| n }
      attrs = {}
      event_params.each do |param|
        attrs[param] = send(param) if respond_to?(param, true)
      end
      @event = event_class.new(**attrs)
      self.class.event_bus&.publish(@event)
      @event
    end

    def record_event_for_aggregate
      recorder = self.class.event_recorder
      agg_type = self.class.aggregate_type
      recorder.record(agg_type, aggregate.id, @event) if recorder && aggregate
    end
  end
end
