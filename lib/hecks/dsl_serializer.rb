# Hecks::DslSerializer
#
# Serializes a built Domain back into DSL source code. Handles all DSL
# constructs: attributes, value objects, validations, invariants, scopes,
# queries, commands (with guarded_by, read models, external systems, actors),
# and reactive policies. Extracted from Session#to_dsl for standalone reuse.
#
# Part of the DSL layer. Used by the console session to dump editable domain
# definitions and by round-trip tooling that loads then re-saves domains.
#
#   domain = Hecks.domain("Pizzas") { ... }
#   DslSerializer.new(domain).serialize
#   # => 'Hecks.domain "Pizzas" do ...'
#
module Hecks
  class DslSerializer
    def initialize(domain)
      @domain = domain
    end

    def serialize
      lines = []
      lines << "Hecks.domain \"#{@domain.name}\" do"

      @domain.aggregates.each_with_index do |agg, i|
        lines << "" if i > 0
        lines << "  aggregate \"#{agg.name}\" do"

        agg.attributes.each do |attr|
          lines << "    attribute :#{attr.name}, #{dsl_type(attr)}"
        end

        agg.value_objects.each do |vo|
          lines << ""
          lines << "    value_object \"#{vo.name}\" do"
          vo.attributes.each do |attr|
            lines << "      attribute :#{attr.name}, #{dsl_type(attr)}"
          end
          vo.invariants.each do |inv|
            lines << ""
            lines << "      invariant \"#{inv.message}\" do"
            lines << "        #{Hecks::Utils.block_source(inv.block)}"
            lines << "      end"
          end
          lines << "    end"
        end

        agg.validations.each do |v|
          lines << ""
          lines << "    validation :#{v.field}, #{v.rules.inspect}"
        end

        agg.invariants.each do |inv|
          lines << ""
          lines << "    invariant \"#{inv.message}\" do"
          lines << "      #{Hecks::Utils.block_source(inv.block)}"
          lines << "    end"
        end

        agg.scopes.each do |s|
          next if s.callable?
          lines << ""
          formatted = s.conditions.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
          lines << "    scope :#{s.name}, #{formatted}"
        end

        agg.queries.each do |q|
          lines << ""
          lines << "    query \"#{q.name}\" do"
          lines << "      #{Hecks::Utils.block_source(q.block)}"
          lines << "    end"
        end

        agg.commands.each do |cmd|
          lines << ""
          lines << "    command \"#{cmd.name}\" do"
          cmd.attributes.each do |attr|
            lines << "      attribute :#{attr.name}, #{dsl_type(attr)}"
          end
          cmd.read_models.each do |rm|
            lines << "      read_model \"#{rm.name}\""
          end
          cmd.external_systems.each do |ext|
            lines << "      external \"#{ext.name}\""
          end
          cmd.actors.each do |act|
            lines << "      actor \"#{act.name}\""
          end
          lines << "    end"
        end

        agg.policies.each do |pol|
          lines << ""
          lines << "    policy \"#{pol.name}\" do"
          lines << "      on \"#{pol.event_name}\""
          lines << "      trigger \"#{pol.trigger_command}\""
          lines << "      async true" if pol.async
          lines << "    end"
        end

        lines << "  end"
      end

      lines << "end"
      lines.join("\n") + "\n"
    end

    private

    def dsl_type(attr)
      if attr.list?
        "list_of(\"#{attr.type}\")"
      elsif attr.reference?
        "reference_to(\"#{attr.type}\")"
      else
        attr.type.to_s
      end
    end
  end
end
