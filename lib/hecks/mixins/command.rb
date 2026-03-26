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

      def preconditions
        @preconditions ||= []
      end

      def postconditions
        @postconditions ||= []
      end

      def precondition(message, &block)
        preconditions << DomainModel::Behavior::Condition.new(message: message, block: block)
      end

      def postcondition(message, &block)
        postconditions << DomainModel::Behavior::Condition.new(message: message, block: block)
      end

      def event_class
        agg_module = name.split("::")[0..-3].join("::")
        Object.const_get("#{agg_module}::Events::#{@event_name}")
      end

      def call(**attrs)
        cmd = new(**attrs)
        cmd.send(:run_guard)
        cmd.send(:run_handler)
        cmd.send(:check_preconditions)
        result = if command_bus && !command_bus.middleware.empty?
          command_bus.dispatch_with_command(cmd) { cmd.call }
        else
          cmd.call
        end
        cmd.instance_variable_set(:@aggregate, result)
        cmd.send(:check_postconditions, cmd.send(:find_existing_for_postcondition), result)
        cmd.send(:persist_aggregate)
        cmd.send(:emit_event)
        cmd.send(:record_event_for_aggregate)
        cmd
      end
    end

    # Chain commands fluently. Yields self to block, returns the block's
    # result (which should be another command). Propagates chain history.
    #   AiModel.register(name: "X").then { |cmd| Assessment.initiate(model_id: cmd.id) }
    def then
      return self if @chain_error
      begin
        result = yield(self)
        result.instance_variable_set(:@chain_steps, steps + [result]) if result.is_a?(self.class) || (result.class.ancestors.include?(Hecks::Command))
        result
      rescue => e
        @chain_error = e
        self
      end
    end

    def success? = @chain_error.nil?
    def steps = @chain_steps || [self]
    def last = steps.last
    def error = @chain_error

    # Delegate unknown methods to aggregate for backward compat.
    # AiModel.register(name: "X").name => aggregate.name
    def method_missing(name, *args, **kwargs, &block)
      if aggregate&.respond_to?(name)
        kwargs.empty? ? aggregate.send(name, *args, &block) : aggregate.send(name, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      aggregate&.respond_to?(name, include_private) || super
    end

    private

    def repository
      self.class.repository
    end

    def check_preconditions
      self.class.preconditions.each do |cond|
        unless instance_exec(&cond.block)
          raise Hecks::PreconditionError, "Precondition failed: #{cond.message}"
        end
      end
    end

    def check_postconditions(before, after)
      self.class.postconditions.each do |cond|
        unless cond.block.call(before, after)
          raise Hecks::PostconditionError, "Postcondition failed: #{cond.message}"
        end
      end
    end

    def find_existing_for_postcondition
      return nil if self.class.postconditions.empty?
      # Try to find the existing aggregate for before/after comparison
      id_method = instance_variables.find { |v| v.to_s.end_with?("_id") }
      return nil unless id_method
      id_val = instance_variable_get(id_method)
      repository&.find(id_val) rescue nil
    end

    def run_guard
      policy_name = self.class.guarded_by
      return unless policy_name

      agg_module = self.class.name.split("::")[0..-3].join("::")
      policy_class = Object.const_get("#{agg_module}::Policies::#{policy_name}")
      result = policy_class.new.call(self)
      unless result
        raise Hecks::GuardRejected, "Guard #{policy_name} rejected #{self.class.name.split('::').last}"
      end
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
        if param == :aggregate_id && aggregate
          attrs[param] = aggregate.id
        elsif respond_to?(param, true)
          attrs[param] = send(param)
        elsif aggregate&.respond_to?(param)
          attrs[param] = aggregate.send(param)
        end
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
