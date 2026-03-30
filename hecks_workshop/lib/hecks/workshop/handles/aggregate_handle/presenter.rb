module Hecks
  class Workshop
    class AggregateHandle
    # Hecks::Workshop::AggregateHandle::Presenter
    #
    # Presentation methods for AggregateHandle: describe (detailed summary with
    # attributes, VOs, entities, commands, validations, invariants, policies,
    # queries, scopes, subscribers, and specifications), inspect (one-line),
    # preview (generated code), valid?/errors (validation), and the type_label
    # helper for formatting types.
    #
    # Mixed into AggregateHandle to separate display logic from builder logic.
    #
    module Presenter
      # Print a detailed summary of the aggregate's structure.
      #
      # Builds the aggregate from its builder and prints all sections:
      # attributes, value objects (with invariants), entities (with invariants),
      # commands (with event mappings), validations, invariants, policies,
      # queries, scopes, subscribers, and specifications.
      #
      # @return [nil]
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
            lines << "    #{cmd.name} -> #{event&.name}"
            cmd.attributes.each do |a|
              lines << "      #{a.name}: #{Hecks::Utils.type_label(a)}"
            end
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

      # Print the generated Ruby code for this aggregate.
      #
      # Uses the AggregateGenerator to produce the code that would be
      # written to a gem for this aggregate, and prints it to stdout.
      #
      # @return [nil]
      def preview
        agg = @builder.build
        domain_module = @domain_module || "Domain"
        gen = Generators::Domain::AggregateGenerator.new(agg, domain_module: domain_module)
        puts gen.generate
        nil
      end

      # Check whether this aggregate has no validation errors.
      #
      # @return [Boolean] true if there are no errors
      def valid?
        errors.empty?
      end

      # Return validation errors relevant to this aggregate.
      #
      # Validates the entire domain via the parent workshop and filters
      # errors to only those mentioning this aggregate's name.
      #
      # @return [Array<String>] error messages related to this aggregate
      def errors
        return [] unless @workshop
        domain = @workshop.to_domain
        validator = Validator.new(domain)
        return [] if validator.valid?
        validator.errors.select { |e| e.include?(@name) }
      end

      # Return a compact string representation of this aggregate handle.
      #
      # @return [String] e.g. "#<Pizza (3 attributes, 2 commands)>"
      def inspect
        "#<#{@name} (#{attributes.size} attributes, #{commands.size} commands)>"
      end

      private

      # Format a type for display in REPL output.
      #
      # Handles plain types (returns their +to_s+), list types
      # ({list: String} -> "list_of(String)"), and reference types
      # ({reference: "Order"} -> "reference_to(Order)").
      #
      # @param type [Class, Hash] the type to format
      # @return [String] human-readable type label
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
