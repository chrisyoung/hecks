# Hecks::ProcessManager
#
# Event-driven state machine that subscribes to the event bus and
# transitions through states by dispatching commands. Unlike SagaRunner
# which executes steps imperatively, ProcessManager reacts to domain
# events and advances a saga instance through declared transitions.
#
# Each transition declares: an event trigger, a command to dispatch,
# an optional source state guard, and a target state.
#
#   pm = ProcessManager.new(saga_def, command_bus, store, event_bus)
#   pm.wire!
#   # Now events on the bus drive the state machine automatically.
#   pm.start(correlation_id: "order-42", item: "Widget")
#
module Hecks
  class ProcessManager
    # @return [Hecks::DomainModel::Behavior::Saga] the saga definition
    attr_reader :saga

    # Creates a new process manager for the given saga definition.
    #
    # @param saga [Hecks::DomainModel::Behavior::Saga] saga IR with transitions
    # @param command_bus [Hecks::Commands::CommandBus] for dispatching commands
    # @param store [Hecks::SagaStore] for persisting saga state
    # @param event_bus [Hecks::EventBus] for subscribing to domain events
    def initialize(saga, command_bus, store, event_bus)
      @saga = saga
      @command_bus = command_bus
      @store = store
      @event_bus = event_bus
    end

    # Subscribes to the event bus for each transition's trigger event.
    # Must be called once at boot time.
    #
    # @return [void]
    def wire!
      @saga.transitions.each do |transition|
        @event_bus.subscribe(transition.event) do |event|
          handle_event(transition, event)
        end
      end
    end

    # Start a new process manager instance. Persists initial state and
    # returns the instance hash.
    #
    # @param correlation_id [String, nil] optional correlation ID (auto-generated if nil)
    # @param attrs [Hash] keyword arguments stored on the instance
    # @return [Hash] the initial process manager instance state
    def start(correlation_id: nil, **attrs)
      cid = correlation_id || generate_id
      instance = new_instance(cid, attrs)
      @store.save(cid, instance)
      instance
    end

    private

    def generate_id
      "pm_#{SecureRandom.hex(8)}"
    end

    def new_instance(correlation_id, attrs)
      {
        saga_id: correlation_id,
        correlation_id: correlation_id,
        saga_name: @saga.name,
        state: "started",
        attrs: attrs,
        completed_transitions: [],
        error: nil
      }
    end

    def handle_event(transition, event)
      instance = find_instance(event)
      return unless instance
      return unless state_matches?(instance, transition)

      begin
        @command_bus.dispatch(transition.command, **instance[:attrs])
        instance[:state] = transition.to
        instance[:completed_transitions] << transition.event
        @store.save(instance[:saga_id], instance)
      rescue => e
        instance[:state] = "failed"
        instance[:error] = "#{transition.command}: #{e.message}"
        @store.save(instance[:saga_id], instance)
      end
    end

    def find_instance(event)
      cid = extract_correlation_id(event)
      return nil unless cid
      @store.find_by_correlation(cid)
    end

    def extract_correlation_id(event)
      if event.respond_to?(:correlation_id)
        event.correlation_id
      elsif event.respond_to?(:[])
        event[:correlation_id]
      end
    end

    def state_matches?(instance, transition)
      return true unless transition.guarded?
      instance[:state] == transition.from
    end
  end
end
