# Hecks::Services::Introspection
#
# Mixin that gives generated aggregate classes runtime introspection.
# Bound by AggregateWiring, backed by the domain IR.
#
#   Pizza.describe              # formatted summary
#   Pizza.domain_commands       # => ["CreatePizza(name: String) -> CreatedPizza"]
#   Pizza.domain_attributes     # => [:name, :style, :toppings]
#   Pizza.domain_value_objects  # => ["Topping (name: String, amount: Integer)"]
#   Pizza.domain_policies       # => ["ReserveIngredients (PlacedOrder -> ReserveStock)"]
#   Pizza.domain_queries        # => ["Classics", "ByStyle"]
#   Pizza.domain_def            # => raw Aggregate IR object
#   Pizza.glossary              # prints domain glossary for this aggregate
#
module Hecks
  module Services
    module Introspection
      def self.bind(klass, agg)
        klass.instance_variable_set(:@__hecks_agg_def__, agg)
        klass.extend(ClassMethods)
      end

      module ClassMethods
        def domain_def
          instance_variable_get(:@__hecks_agg_def__)
        end

        def describe
          agg = domain_def
          lines = []
          lines << agg.name
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
              vo.invariants.each { |inv| lines << "      invariant: #{inv.message}" }
            end
          end

          unless agg.entities.empty?
            lines << "  Entities:"
            agg.entities.each do |ent|
              attrs = ent.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
              lines << "    #{ent.name} (#{attrs})"
              ent.invariants.each { |inv| lines << "      invariant: #{inv.message}" }
            end
          end

          unless agg.commands.empty?
            lines << "  Commands:"
            agg.commands.each_with_index do |cmd, i|
              event = agg.events[i]
              attrs = cmd.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
              lines << "    #{cmd.name}(#{attrs}) -> #{event&.name}"
            end
          end

          unless agg.queries.empty?
            lines << "  Queries:"
            agg.queries.each { |q| lines << "    #{q.name}" }
          end

          unless agg.validations.empty?
            lines << "  Validations:"
            agg.validations.each do |v|
              lines << "    #{v.field}: #{v.rules.keys.join(', ')}"
            end
          end

          unless agg.invariants.empty?
            lines << "  Invariants:"
            agg.invariants.each { |inv| lines << "    #{inv.message}" }
          end

          unless agg.policies.empty?
            lines << "  Policies:"
            agg.policies.each do |pol|
              async_label = pol.async ? " [async]" : ""
              lines << "    #{pol.name} (#{pol.event_name} -> #{pol.trigger_command})#{async_label}"
            end
          end

          unless agg.specifications.empty?
            lines << "  Specifications:"
            agg.specifications.each { |s| lines << "    #{s.name}" }
          end

          puts lines.join("\n")
          nil
        end

        def domain_attributes
          domain_def.attributes.map { |a| a.name.to_sym }
        end

        def domain_commands
          agg = domain_def
          agg.commands.each_with_index.map do |cmd, i|
            event = agg.events[i]
            attrs = cmd.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            "#{cmd.name}(#{attrs}) -> #{event&.name}"
          end
        end

        def domain_queries
          domain_def.queries.map(&:name)
        end

        def domain_entities
          domain_def.entities.map do |ent|
            attrs = ent.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            "#{ent.name} (#{attrs})"
          end
        end

        def domain_value_objects
          domain_def.value_objects.map do |vo|
            attrs = vo.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            "#{vo.name} (#{attrs})"
          end
        end

        def domain_specifications
          domain_def.specifications.map(&:name)
        end

        def domain_policies
          domain_def.policies.map do |pol|
            async_label = pol.async ? " [async]" : ""
            "#{pol.name} (#{pol.event_name} -> #{pol.trigger_command})#{async_label}"
          end
        end

        def glossary
          Hecks::DomainGlossary.new(nil).print_for(domain_def)
        end
      end
    end
  end
end
