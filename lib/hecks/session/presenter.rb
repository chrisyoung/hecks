# Hecks::Session::Presenter
#
# Module providing presentation methods for Session: describe, status,
# and inspect. Formats domain state for human-readable output.
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
