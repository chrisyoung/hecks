# Hecks::Session::Playground
#
# Live execution sandbox that compiles a domain model into real Ruby classes,
# boots a full Runtime with memory adapters, and lets you execute commands
# with real persistence. Used by Session's "play" mode for rapid prototyping.
#
# Generates a temp gem, loads it, then creates a Runtime that wires
# persistence, commands, queries, and the event bus. Aggregates are
# persisted in memory — find, all, count, where all work.
#
# Mixins:
#   GemBootstrap    — temp gem compilation and loading (compile!)
#   RuntimeResolver — command/event class resolution and policy checking
#
#   playground = Hecks::Session::Playground.new(domain)
#   playground.execute("CreatePizza", name: "Margherita")
#   Pizza.find(id)         # works — persisted in memory
#   Pizza.all              # works
#   playground.events      # => [#<CreatedPizza ...>]
#   playground.reset!      # clears events and repositories
#
require_relative "playground/gem_bootstrap"
require_relative "playground/runtime_resolver"

module Hecks
  class Session
    class Playground
    include GemBootstrap
    include RuntimeResolver

    attr_reader :events, :runtime

    def initialize(domain)
      @domain = domain
      @mod_name = domain.module_name + "Domain"
      @events = []
      @policies = collect_policies
      compile!
      boot_runtime!
    end

    # Execute a command by name, returns the aggregate
    def execute(command_name, **attrs)
      agg_def = @domain.aggregates.find do |a|
        a.commands.any? { |c| c.name == command_name.to_s }
      end
      unless agg_def
        available = @domain.aggregates.flat_map { |a| a.commands.map(&:name) }
        raise "Unknown command: #{command_name}. Available: #{available.join(', ')}"
      end

      mod = Object.const_get(@mod_name)
      agg_class = mod.const_get(Hecks::Utils.sanitize_constant(agg_def.name))
      agg_snake = Hecks::Utils.underscore(agg_def.name)
      method_name = Hecks::Utils.underscore(command_name).sub(/_#{agg_snake}$/, "").to_sym

      result = agg_class.send(method_name, **attrs)

      event = @events.last
      if event
        event_name = event.class.name.split("::").last
        puts "Command: #{command_name}"
        puts "  Event: #{event_name}"
        attrs.each { |k, v| puts "    #{k}: #{v.inspect}" }
        puts "    occurred_at: #{event.occurred_at}"

        triggered = check_policies(event)
        triggered.each do |policy|
          puts "  Policy: #{policy.name} -> #{policy.trigger_command}"
        end
      end

      result
    end

    # List available commands
    def commands
      @domain.aggregates.flat_map do |agg|
        agg.commands.map do |cmd|
          event = agg.events.find { |e| e.name == cmd.inferred_event_name }
          attrs = cmd.attributes.map { |a| "#{a.name}: #{a.type}" }.join(", ")
          "#{cmd.name}(#{attrs}) -> #{event&.name}"
        end
      end
    end

    # Get all events of a specific type
    def events_of(type_name)
      @events.select { |e| e.class.name.split("::").last == type_name }
    end

    # Clear all events and repository data
    def reset!
      @events.clear
      @domain.aggregates.each do |agg|
        repo = @runtime[agg.name]
        repo.clear if repo.respond_to?(:clear)
      end
      puts "Cleared all events and data"
    end

    # Show a summary of what's happened
    def history
      if @events.empty?
        puts "No events yet"
        return
      end

      @events.each_with_index do |event, i|
        name = event.class.name.split("::").last
        puts "#{i + 1}. #{name} at #{event.occurred_at}"
      end
      nil
    end

    def inspect
      "#<Hecks::Session::Playground \"#{@domain.name}\" (#{@events.size} events)>"
    end

    private

    # Boot a full Runtime with memory adapters, capturing all events
    def boot_runtime!
      playground_events = @events
      bus = EventBus.new

      # Intercept publish to capture every event into playground's list
      original_publish = bus.method(:publish)
      bus.define_singleton_method(:publish) do |event|
        original_publish.call(event)
        playground_events << event
      end

      @runtime = Runtime.new(@domain, event_bus: bus)
    end
  end
  end
end
