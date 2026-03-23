# Hecks::Playground
#
# Live execution sandbox that compiles a domain model into real Ruby classes,
# then lets you execute commands and inspect the resulting events. Used by
# Session's "play" mode for rapid prototyping.
#
# Sits between the Generators (which produce source code) and the runtime --
# it generates a temp gem, loads it, and provides a command/event interface.
#
#   playground = Hecks::Playground.new(domain)
#   playground.execute("CreatePizza", name: "Margherita")
#   playground.events      # => [#<CreatedPizza ...>]
#   playground.commands    # => ["CreatePizza(name: String) -> CreatedPizza"]
#   playground.history     # prints numbered event timeline
#   playground.reset!      # clears all events
#
require "tmpdir"

module Hecks
  class Playground
    attr_reader :events

    def initialize(domain)
      @domain = domain
      @mod_name = domain.module_name + "Domain"
      @events = []
      @policies = collect_policies
      compile!
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
            .reject { |m| m == :freeze }
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
      "#<Hecks::Playground \"#{@domain.name}\" (#{@events.size} events)>"
    end

    private

    def compile!
      @tmpdir = Dir.mktmpdir("hecks_playground")
      generator = Generators::Infrastructure::DomainGemGenerator.new(@domain, version: "0.0.0", output_dir: @tmpdir)
      gem_path = generator.generate

      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

      entry = File.join(lib_path, "#{@domain.gem_name}.rb")
      load entry

      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    end

    def resolve_command(command_name)
      mod = Object.const_get(@mod_name)

      @domain.contexts.each do |ctx|
        ctx.aggregates.each do |agg|
          agg_class = resolve_agg_class(mod, ctx, agg)
          if agg_class.const_defined?(:Commands) &&
             agg_class::Commands.const_defined?(command_name)
            return agg_class::Commands.const_get(command_name)
          end
        end
      end

      raise "Unknown command: #{command_name}. Available: #{available_commands.join(', ')}"
    end

    def resolve_event_for(command_name)
      mod = Object.const_get(@mod_name)

      @domain.contexts.each do |ctx|
        ctx.aggregates.each do |agg|
          agg.commands.each_with_index do |cmd, i|
            if cmd.name == command_name.to_s
              event = agg.events[i]
              agg_class = resolve_agg_class(mod, ctx, agg)
              return agg_class::Events.const_get(event.name)
            end
          end
        end
      end

      raise "No event mapped for command: #{command_name}"
    end

    def resolve_agg_class(mod, ctx, agg)
      if ctx.default?
        mod.const_get(agg.name)
      else
        mod.const_get(ctx.module_name).const_get(agg.name)
      end
    end

    def resolve_domain_command(command_name)
      @domain.contexts.each do |ctx|
        ctx.aggregates.each do |agg|
          agg.commands.each do |cmd|
            return cmd if cmd.name == command_name.to_s
          end
        end
      end
      nil
    end

    def available_commands
      @domain.aggregates.flat_map { |a| a.commands.map(&:name) }
    end

    def collect_policies
      @domain.aggregates.flat_map(&:policies)
    end

    def check_policies(event)
      event_name = event.class.name.split("::").last
      @policies.select { |p| p.event_name == event_name }
    end
  end
end
