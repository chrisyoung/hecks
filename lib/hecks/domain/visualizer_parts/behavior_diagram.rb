# Hecks::DomainVisualizer::BehaviorDiagram
#
# Builds the Mermaid flowchart portion showing command-to-event flows
# and policy chains (event triggers command).
#
#   include BehaviorDiagram
#   generate_behavior  # => "flowchart LR\n    subgraph Pizza\n    ..."
#
module Hecks
  class DomainVisualizer
    module BehaviorDiagram
      private

      def generate_behavior
        lines = ["flowchart LR"]

        @domain.aggregates.each do |agg|
          prefix = agg.name
          lines << "    subgraph #{prefix}"

          agg.commands.each_with_index do |cmd, i|
            event = agg.events[i]
            cmd_id = node_id(prefix, cmd.name)
            lines << "        #{cmd_id}[#{cmd.name}]"

            if event
              evt_id = node_id(prefix, event.name)
              lines << "        #{evt_id}([#{event.name}])"
              lines << "        #{cmd_id} --> #{evt_id}"
            end
          end

          lines << "    end"
        end

        policy_links(lines)
        lines.join("\n")
      end

      def policy_links(lines)
        all_policies = @domain.aggregates.flat_map(&:policies) + @domain.policies

        all_policies.each do |pol|
          evt_agg, evt_id = find_event_node(pol.event_name)
          cmd_agg, cmd_id = find_command_node(pol.trigger_command)
          next unless evt_id && cmd_id

          label = pol.async ? "#{pol.name} [async]" : pol.name
          lines << "    #{evt_id} -.->|#{label}| #{cmd_id}"
        end
      end

      def find_event_node(event_name)
        @domain.aggregates.each do |agg|
          agg.events.each do |evt|
            return [agg.name, node_id(agg.name, evt.name)] if evt.name == event_name
          end
        end
        nil
      end

      def find_command_node(command_name)
        @domain.aggregates.each do |agg|
          agg.commands.each do |cmd|
            return [agg.name, node_id(agg.name, cmd.name)] if cmd.name == command_name
          end
        end
        nil
      end

      def node_id(prefix, name)
        "#{prefix}_#{name}"
      end
    end
  end
end
