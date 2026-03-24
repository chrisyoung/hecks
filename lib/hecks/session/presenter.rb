# Hecks::Session::Presenter
#
# Session mixin for human-readable output: describe, status, and inspect.
# Part of the Session layer -- formats aggregate, command, policy, query,
# scope, and subscriber summaries for REPL display.
#
#   session.describe   # prints full domain summary
#   session.status     # alias for describe
#
module Hecks
  class Session
    module Presenter
      # Describe the entire domain
      def describe
        domain = to_domain

        lines = []
        lines << "#{@name} Domain"
        lines << ""

        domain.aggregates.each do |agg|
          handle = @handles[agg.name] || AggregateHandle.new(agg.name, @aggregate_builders[agg.name], domain_module: @name.gsub(/\s+/, "") + "Domain")
          lines << "  #{agg.name}"

          unless agg.attributes.empty?
            attrs = agg.attributes.map { |a| "#{a.name} (#{Hecks::Utils.type_label(a)})" }.join(", ")
            lines << "    Attributes: #{attrs}"
          end

          unless agg.value_objects.empty?
            agg.value_objects.each do |vo|
              vo_attrs = vo.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
              lines << "    Value Objects: #{vo.name} (#{vo_attrs})"
            end
          end

          unless agg.entities.empty?
            agg.entities.each do |ent|
              ent_attrs = ent.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
              lines << "    Entities: #{ent.name} (#{ent_attrs})"
            end
          end

          unless agg.commands.empty?
            agg.commands.each_with_index do |cmd, i|
              event = agg.events[i]
              lines << "    Commands: #{cmd.name} -> #{event&.name}"
            end
          end

          unless agg.validations.empty?
            vals = agg.validations.map { |v| "#{v.field} (#{v.rules.keys.join(', ')})" }.join(", ")
            lines << "    Validations: #{vals}"
          end

          unless agg.policies.empty?
            agg.policies.each do |pol|
              lines << "    Policies: #{pol.name} (on #{pol.event_name} -> #{pol.trigger_command})"
            end
          end

          unless agg.queries.empty?
            queries = agg.queries.map(&:name).join(", ")
            lines << "    Queries: #{queries}"
          end

          unless agg.scopes.empty?
            scopes = agg.scopes.map(&:name).join(", ")
            lines << "    Scopes: #{scopes}"
          end

          unless agg.subscribers.empty?
            subs = agg.subscribers.map { |s| "on #{s.event_name}" }.join(", ")
            lines << "    Subscribers: #{subs}"
          end

          lines << ""
        end

        unless domain.policies.empty?
          lines << "  Domain Policies:"
          domain.policies.each do |pol|
            lines << "    #{pol.name} (on #{pol.event_name} -> #{pol.trigger_command})"
          end
          lines << ""
        end

        puts lines.join("\n")
        nil
      end

      # Show current domain state (alias for describe)
      def status
        describe
      end

      def inspect
        mode_label = play? ? "play" : "build"
        "#<Hecks::Session \"#{@name}\" [#{mode_label}] (#{@aggregate_builders.size} aggregates)>"
      end
    end
  end
end
