# Hecks::Session::AggregateHandle::Presenter
#
# Presentation methods for AggregateHandle: describe (detailed summary with
# attributes, VOs, entities, commands, validations, invariants, policies,
# queries, scopes, subscribers, and specifications), inspect (one-line),
# and the type_label helper for formatting types.
#
module Hecks
  class Session
    class AggregateHandle
    module Presenter
      def describe
        agg = @builder.build
        lines = []
        lines << @name
        lines << ""

        unless agg.attributes.empty?
          lines << "  Attributes:"
          agg.attributes.each do |attr|
            lines << "    #{attr.name}: #{Hecks::Utils.type_label(attr)}"
          end
        end

        unless agg.value_objects.empty?
          lines << "  Value Objects:"
          agg.value_objects.each do |vo|
            attrs = vo.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            lines << "    #{vo.name} (#{attrs})"
            vo.invariants.each do |inv|
              lines << "      invariant: #{inv.message}"
            end
          end
        end

        unless agg.entities.empty?
          lines << "  Entities:"
          agg.entities.each do |ent|
            attrs = ent.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            lines << "    #{ent.name} (#{attrs})"
            ent.invariants.each do |inv|
              lines << "      invariant: #{inv.message}"
            end
          end
        end

        unless agg.commands.empty?
          lines << "  Commands:"
          agg.commands.each_with_index do |cmd, i|
            event = agg.events[i]
            attrs = cmd.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            lines << "    #{cmd.name} (#{attrs}) -> #{event&.name}"
          end
        end

        unless agg.validations.empty?
          lines << "  Validations:"
          agg.validations.each do |v|
            lines << "    #{v.field}: #{v.rules.keys.join(', ')}"
          end
        end

        unless agg.invariants.empty?
          lines << "  Invariants:"
          agg.invariants.each do |inv|
            lines << "    #{inv.message}"
          end
        end

        unless agg.policies.empty?
          lines << "  Policies:"
          agg.policies.each do |pol|
            lines << "    #{pol.name} (on #{pol.event_name} -> #{pol.trigger_command})"
          end
        end

        unless agg.queries.empty?
          lines << "  Queries:"
          agg.queries.each { |q| lines << "    #{q.name}" }
        end

        unless agg.scopes.empty?
          lines << "  Scopes:"
          agg.scopes.each { |s| lines << "    #{s.name}" }
        end

        unless agg.subscribers.empty?
          lines << "  Subscribers:"
          agg.subscribers.each { |s| lines << "    on #{s.event_name}" }
        end

        unless agg.specifications.empty?
          lines << "  Specifications:"
          agg.specifications.each { |s| lines << "    #{s.name}" }
        end

        puts lines.join("\n")
        nil
      end

      def preview
        agg = @builder.build
        domain_module = @domain_module || "Domain"
        gen = Generators::Domain::AggregateGenerator.new(agg, domain_module: domain_module)
        puts gen.generate
        nil
      end

      def valid?
        errors.empty?
      end

      def errors
        return [] unless @session
        domain = @session.to_domain
        validator = Validator.new(domain)
        return [] if validator.valid?
        validator.errors.select { |e| e.include?(@name) }
      end

      def inspect
        "#<#{@name} (#{attributes.size} attributes, #{commands.size} commands)>"
      end

      private

      def type_label(type)
        case type
        when Hash
          if type[:list]
            "list_of(#{type[:list]})"
          elsif type[:reference]
            "reference_to(#{type[:reference]})"
          else
            type.to_s
          end
        else
          type.to_s
        end
      end
    end
    end
  end
end
