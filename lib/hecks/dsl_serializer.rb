# Hecks::DslSerializer
#
# Serializes a built Domain back into DSL source code. Extracted from
# Session#to_dsl so the serialization logic can be reused independently
# of any interactive session state.
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

        agg.commands.each do |cmd|
          lines << ""
          lines << "    command \"#{cmd.name}\" do"
          cmd.attributes.each do |attr|
            lines << "      attribute :#{attr.name}, #{dsl_type(attr)}"
          end
          lines << "    end"
        end

        agg.policies.each do |pol|
          lines << ""
          lines << "    policy \"#{pol.name}\" do"
          lines << "      on \"#{pol.event_name}\""
          lines << "      trigger \"#{pol.trigger_command}\""
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
