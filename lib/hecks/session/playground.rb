# Hecks::Session::Playground
#
# Live execution sandbox that compiles a domain model into real Ruby classes,
# then lets you execute commands and inspect the resulting events. Used by
# Session's "play" mode for rapid prototyping.
#
# Sits between the Generators (which produce source code) and the runtime --
# it generates a temp gem, loads it, and provides a command/event interface.
#
# Mixins:
#   GemBootstrap    — temp gem compilation and loading (compile!)
#   RuntimeResolver — command/event class resolution and policy checking
#
#   playground = Hecks::Session::Playground.new(domain)
#   playground.execute("CreatePizza", name: "Margherita")
#   playground.events      # => [#<CreatedPizza ...>]
#   playground.commands    # => ["CreatePizza(name: String) -> CreatedPizza"]
#   playground.history     # prints numbered event timeline
#   playground.reset!      # clears all events
#
require_relative "playground/gem_bootstrap"
require_relative "playground/runtime_resolver"

module Hecks
  class Session
    class Playground
    include GemBootstrap
    include RuntimeResolver

    attr_reader :events

    def initialize(domain)
      @domain = domain
      @mod_name = domain.module_name + "Domain"
      @events = []
      @policies = collect_policies
      compile!
      wire_commands!
    end

    # Execute a command by name, returns the event
    def execute(command_name, **attrs)
      domain_cmd = resolve_domain_command(command_name)
      if domain_cmd&.handler
        require "ostruct"
        domain_cmd.handler.call(OpenStruct.new(**attrs))
      end

      cmd_class = resolve_command(command_name)
      command = cmd_class.new(**attrs)

      event_class = resolve_event_for(command_name)
      event_attrs = {}
      command.class.instance_methods(false)
            .reject { |m| %i[freeze call].include?(m) }
            .select { |m| command.class.method_defined?(m) }
            .each do |m|
        next if m.to_s.end_with?("=")
        val = command.send(m)
        if event_class.instance_method(:initialize).parameters.any? { |_, n| n == m }
          event_attrs[m] = val
        end
      end

      event = event_class.new(**event_attrs)
      @events << event

      puts "Command: #{command_name}"
      puts "  Event: #{event.class.name.split('::').last}"
      event_attrs.each { |k, v| puts "    #{k}: #{v.inspect}" }
      puts "    occurred_at: #{event.occurred_at}"

      triggered = check_policies(event)
      triggered.each do |policy|
        puts "  Policy: #{policy.name} -> #{policy.trigger_command}"
      end

      event
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

    # Clear all events
    def reset!
      @events.clear
      puts "Cleared all events"
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

    # Wire shortcut methods onto aggregate classes so instances can call
    # commands directly: cat.meow delegates to playground.execute("Meow").
    def wire_commands!
      mod = Object.const_get(@mod_name)
      playground = self

      @domain.aggregates.each do |agg|
        klass = mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
        Services::Commands::CommandMethods.bind_shortcuts(klass, agg) do |cmd|
          cmd_name = cmd.name
          ->(attrs) { playground.execute(cmd_name, **attrs) }
        end
      end
    end
  end
  end
end
