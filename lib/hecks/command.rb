# Hecks::Command
#
# Mixin for generated command classes. Orchestrates the full command lifecycle:
# run guard policy, run handler, execute call (with optional middleware),
# persist aggregate, emit event, and record event.
# The generated call method is pure domain logic — just build and return
# the aggregate.
#
#   class CreatePizza
#     emits "CreatedPizza"
#
#     def call
#       Pizza.new(name: name)
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
      attr_accessor :repository, :event_bus, :handler, :guarded_by,
                    :event_recorder, :aggregate_type, :command_bus

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
        cmd.send(:run_guard)
        cmd.send(:run_handler)
        result = if command_bus && !command_bus.middleware.empty?
          command_bus.dispatch_with_command(cmd) { cmd.call }
        else
          cmd.call
        end
        cmd.instance_variable_set(:@aggregate, result)
        cmd.send(:persist_aggregate)
        cmd.send(:emit_event)
        cmd.send(:record_event_for_aggregate)
        cmd
      end
    end

    private

    def repository
      self.class.repository
    end

    def run_guard
      policy_name = self.class.guarded_by
      return unless policy_name

      agg_module = self.class.name.split("::")[0..-3].join("::")
      policy_class = Object.const_get("#{agg_module}::Policies::#{policy_name}")
      policy_class.new.call(self)
    end

    def run_handler
      self.class.handler&.call(self)
    end

    def persist_aggregate
      return unless aggregate
      if aggregate.respond_to?(:stamp_created!) && aggregate.created_at.nil?
        aggregate.stamp_created!
      elsif aggregate.respond_to?(:stamp_updated!)
        aggregate.stamp_updated!
      end
      repository.save(aggregate)
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
