# Hecks::Introspection
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
  # Provides runtime introspection capabilities for generated aggregate classes.
  # When bound to a class via +.bind+, it stores the aggregate IR definition on
  # the class and extends it with +ClassMethods+ that expose domain metadata:
  # attributes, commands, queries, entities, value objects, specifications,
  # policies, and a full formatted description.
  #
  # This is particularly useful for AI agents and developer tooling that need
  # to understand the domain model at runtime without reading DSL source files.
  module Introspection
      # Binds introspection methods to a generated aggregate class by storing
      # the aggregate IR definition and extending the class with +ClassMethods+.
      #
      # @param klass [Class] the generated aggregate class to bind introspection to
      # @param agg [Hecks::DomainModel::Structure::Aggregate] the aggregate IR definition
      # @return [void]
      def self.bind(klass, agg)
        klass.instance_variable_set(:@__hecks_agg_def__, agg)
        klass.extend(ClassMethods)
      end

      # Class-level introspection methods extended onto aggregate classes.
      # Provides read access to the domain IR and formatted output methods
      # for commands, attributes, queries, entities, value objects, policies,
      # specifications, invariants, scopes, and subscribers.
      module ClassMethods
        # Returns the raw aggregate IR definition object. This is the compiled
        # intermediate representation from the domain DSL, containing all
        # metadata about this aggregate's structure and behavior.
        #
        # @return [Hecks::DomainModel::Structure::Aggregate] the aggregate IR definition
        def domain_def
          instance_variable_get(:@__hecks_agg_def__)
        end

        # Prints a comprehensive formatted summary of the aggregate to stdout.
        # Includes: attributes, value objects, entities, commands with their events,
        # queries, validations, invariants, policies, scopes, subscribers, and
        # specifications.
        #
        # @return [nil]
        def describe
          agg = domain_def
          lines = []
          lines << agg.name
          lines << ""

          unless agg.attributes.empty?
            lines << "  Attributes:"
            agg.attributes.each do |attr|
              label = "    #{attr.name}: #{Hecks::Utils.type_label(attr)}"
              label += " [masked]" if attr.masked?
              lines << label
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

        # Returns the attribute names defined on this aggregate as symbols.
        #
        # @return [Array<Symbol>] list of attribute name symbols (e.g., [:name, :style, :toppings])
        def domain_attributes
          domain_def.attributes.map { |a| a.name.to_sym }
        end

        # Returns formatted strings describing each command defined on this aggregate,
        # including parameter types and the resulting event name.
        #
        # @return [Array<String>] formatted command descriptions
        #   (e.g., ["CreatePizza(name: String, style: Symbol) -> PizzaCreated"])
        def domain_commands
          agg = domain_def
          agg.commands.each_with_index.map do |cmd, i|
            event = agg.events[i]
            attrs = cmd.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            "#{cmd.name}(#{attrs}) -> #{event&.name}"
          end
        end

        # Returns the names of all queries defined on this aggregate.
        #
        # @return [Array<String>] query names (e.g., ["Classics", "ByStyle"])
        def domain_queries
          domain_def.queries.map(&:name)
        end

        # Returns formatted strings describing each entity within this aggregate,
        # including their attribute names and types.
        #
        # @return [Array<String>] formatted entity descriptions
        #   (e.g., ["LineItem (product: String, quantity: Integer)"])
        def domain_entities
          domain_def.entities.map do |ent|
            attrs = ent.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            "#{ent.name} (#{attrs})"
          end
        end

        # Returns formatted strings describing each value object within this aggregate,
        # including their attribute names and types.
        #
        # @return [Array<String>] formatted value object descriptions
        #   (e.g., ["Topping (name: String, amount: Integer)"])
        def domain_value_objects
          domain_def.value_objects.map do |vo|
            attrs = vo.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            "#{vo.name} (#{attrs})"
          end
        end

        # Returns the names of all specifications defined on this aggregate.
        #
        # @return [Array<String>] specification names (e.g., ["IsVegetarian", "HasToppings"])
        def domain_specifications
          domain_def.specifications.map(&:name)
        end

        # Returns formatted strings describing each policy defined on this aggregate,
        # including the triggering event, the resulting command, and whether it is async.
        #
        # @return [Array<String>] formatted policy descriptions
        #   (e.g., ["ReserveIngredients (PizzaOrdered -> ReserveStock) [async]"])
        def domain_policies
          domain_def.policies.map do |pol|
            async_label = pol.async ? " [async]" : ""
            "#{pol.name} (#{pol.event_name} -> #{pol.trigger_command})#{async_label}"
          end
        end

        # Prints the domain glossary for this aggregate, showing all terms
        # and their definitions as defined in the domain DSL.
        #
        # @return [void]
        def glossary
          Hecks::DomainGlossary.new(nil).print_for(domain_def)
        end
      end
  end
end
