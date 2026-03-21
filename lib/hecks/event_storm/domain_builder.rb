# Hecks::EventStorm::DomainBuilder
#
# Builds a DomainModel::Domain from a Parser::ParseResult. Groups commands
# under their aggregates, wires policies, attaches read models and external
# systems, and validates that event names match command inferences.
#
# Part of the EventStorm module. Used by Hecks.from_event_storm to produce
# the in-memory domain object.
#
#   result = EventStorm::Parser.new(source).parse
#   domain = EventStorm::DomainBuilder.new(result, name: "Ordering").build
#
module Hecks
  module EventStorm
    class DomainBuilder
      def initialize(parse_result, name: nil)
        @parse_result = parse_result
        @name = name || parse_result.domain_name || "MyDomain"
        @warnings = parse_result.warnings
      end

      def build
        contexts = @parse_result.contexts.map { |ctx| build_context(ctx) }
        DomainModel::Domain.new(name: @name, contexts: contexts)
      end

      private

      def build_context(parsed_context)
        aggregates = group_by_aggregate(parsed_context.elements)
        DomainModel::BoundedContext.new(
          name: parsed_context.name,
          aggregates: aggregates
        )
      end

      def group_by_aggregate(elements)
        aggregate_commands = {}
        aggregate_policies = {}
        unassigned_commands = []

        elements.each do |el|
          case el.type
          when :command
            agg_name = el.meta[:aggregate]
            if agg_name
              aggregate_commands[agg_name] ||= []
              aggregate_commands[agg_name] << build_command(el)
            else
              unassigned_commands << build_command(el)
            end
          when :policy
            trigger = el.meta[:trigger]
            # Find which aggregate owns the trigger command
            agg_name = find_aggregate_for_trigger(elements, trigger)
            target = agg_name || "Default"
            aggregate_policies[target] ||= []
            aggregate_policies[target] << build_policy(el)
          end
        end

        validate_events(elements)

        all_agg_names = (aggregate_commands.keys + aggregate_policies.keys).uniq
        all_agg_names << "Default" unless unassigned_commands.empty? || all_agg_names.any?

        all_agg_names.map do |agg_name|
          commands = aggregate_commands.fetch(agg_name, [])
          commands += unassigned_commands if agg_name == all_agg_names.first && !unassigned_commands.empty?
          policies = aggregate_policies.fetch(agg_name, [])

          DomainModel::Aggregate.new(
            name: agg_name,
            commands: commands,
            events: infer_events(commands),
            policies: policies
          )
        end
      end

      def build_command(element)
        read_models = (element.meta[:read_models] || []).map do |name|
          DomainModel::ReadModel.new(name: name)
        end
        externals = (element.meta[:external_systems] || []).map do |name|
          DomainModel::ExternalSystem.new(name: name)
        end

        DomainModel::Command.new(
          name: element.name,
          read_models: read_models,
          external_systems: externals
        )
      end

      def build_policy(element)
        DomainModel::Policy.new(
          name: element.name,
          event_name: element.meta[:event_name],
          trigger_command: element.meta[:trigger]
        )
      end

      def find_aggregate_for_trigger(elements, trigger_name)
        elements.each do |el|
          next unless el.type == :command && el.name == trigger_name
          return el.meta[:aggregate] if el.meta[:aggregate]
        end
        nil
      end

      def infer_events(commands)
        commands.map do |cmd|
          DomainModel::DomainEvent.new(
            name: cmd.inferred_event_name,
            attributes: cmd.attributes
          )
        end
      end

      def validate_events(elements)
        storm_events = elements.select { |e| e.type == :event }.map(&:name)
        commands = elements.select { |e| e.type == :command }

        inferred = {}
        commands.each do |cmd|
          dummy = DomainModel::Command.new(name: cmd.name)
          inferred[dummy.inferred_event_name] = cmd.name
        end

        storm_events.each do |event_name|
          next if inferred.key?(event_name)

          close = inferred.keys.find { |k| k.downcase == event_name.downcase }
          if close
            @warnings << "Event '#{event_name}' doesn't match inferred '#{close}' from command '#{inferred[close]}' (case mismatch)"
          else
            @warnings << "Event '#{event_name}' has no matching command (expected a command that infers this event)"
          end
        end
      end
    end
  end
end
