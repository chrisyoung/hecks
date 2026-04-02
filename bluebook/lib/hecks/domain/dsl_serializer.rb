module Hecks
  # Hecks::DslSerializer
  #
  # Serializes a Domain IR back into DSL source code. The output is valid
  # Ruby that can be eval'd to reconstruct the domain.
  #
  #   DslSerializer.new(domain).serialize
  #   # => 'Hecks.domain "Pizzas" do ...'
  #
  class DslSerializer
    def initialize(domain)
      @domain = domain
    end

    # @return [String] valid Ruby DSL source code
    def serialize
      lines = ["Hecks.domain \"#{@domain.name}\" do"]
      module_agg_names = @domain.modules.flat_map(&:aggregate_names)

      @domain.modules.each_with_index do |mod, mi|
        lines << "" if mi > 0
        lines.concat(serialize_domain_module(mod))
      end

      ungrouped = @domain.aggregates.reject { |a| module_agg_names.include?(a.name) }
      ungrouped.each_with_index do |agg, i|
        lines << "" if i > 0 || @domain.modules.any?
        lines.concat(serialize_aggregate(agg))
      end

      @domain.policies.each { |pol| lines.concat(serialize_domain_policy(pol)) }
      lines << "end"
      lines.join("\n") + "\n"
    end

    private

    def serialize_domain_module(mod)
      aggs = @domain.aggregates.select { |a| mod.aggregate_names.include?(a.name) }
      lines = ["  domain_module \"#{mod.name}\" do"]
      aggs.each_with_index do |agg, i|
        lines << "" if i > 0
        lines.concat(serialize_aggregate(agg, indent: "    "))
      end
      lines << "  end"
      lines
    end

    def serialize_aggregate(agg, indent: "  ")
      inner = indent + "  "
      lines = ["#{indent}aggregate \"#{agg.name}\" do"]
      lines.concat(serialize_attributes(agg.attributes, inner))
      lines.concat(serialize_references(agg.references, inner))
      lines.concat(serialize_value_objects(agg.value_objects, inner))
      lines.concat(serialize_entities(agg.entities, inner))
      lines.concat(serialize_validations(agg.validations, inner))
      lines.concat(serialize_invariants(agg.invariants, inner))
      lines.concat(serialize_scopes(agg.scopes, inner))
      lines.concat(serialize_computed_attributes(agg.computed_attributes, inner))
      lines.concat(serialize_queries(agg.queries, inner))
      lines.concat(serialize_specifications(agg.specifications, inner))
      lines.concat(serialize_commands(agg.commands, inner))
      lines.concat(serialize_policies(agg.policies, inner))
      lines.concat(serialize_subscribers(agg.subscribers, inner))
      lines << "#{indent}end"
      lines
    end

    def serialize_attributes(attrs, indent)
      attrs.map { |a| "#{indent}attribute :#{a.name}, #{dsl_type(a)}" }
    end

    def serialize_value_objects(vos, indent)
      vos.flat_map do |vo|
        inner = indent + "  "
        lines = ["", "#{indent}value_object \"#{vo.name}\" do"]
        lines.concat(serialize_attributes(vo.attributes, inner))
        lines.concat(serialize_invariants(vo.invariants, inner))
        lines << "#{indent}end"
      end
    end

    def serialize_entities(entities, indent)
      entities.flat_map do |ent|
        inner = indent + "  "
        lines = ["", "#{indent}entity \"#{ent.name}\" do"]
        lines.concat(serialize_attributes(ent.attributes, inner))
        lines.concat(serialize_invariants(ent.invariants, inner))
        lines << "#{indent}end"
      end
    end

    def serialize_validations(validations, indent)
      validations.map { |v| ["", "#{indent}validation :#{v.field}, #{v.rules.inspect}"] }.flatten
    end

    def serialize_invariants(invariants, indent)
      invariants.flat_map do |inv|
        ["", "#{indent}invariant \"#{inv.message}\" do",
         "#{indent}  #{Hecks::Utils.block_source(inv.block)}",
         "#{indent}end"]
      end
    end

    def serialize_scopes(scopes, indent)
      scopes.reject(&:callable?).flat_map do |s|
        formatted = s.conditions.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        ["", "#{indent}scope :#{s.name}, #{formatted}"]
      end
    end

    def serialize_queries(queries, indent)
      inner = indent + "  "
      queries.flat_map do |q|
        ["", "#{indent}query \"#{q.name}\" do",
         "#{inner}#{Hecks::Utils.block_source(q.block)}",
         "#{indent}end"]
      end
    end

    def serialize_computed_attributes(computed_attrs, indent)
      inner = indent + "  "
      (computed_attrs || []).flat_map do |ca|
        ["", "#{indent}computed :#{ca.name} do",
         "#{inner}#{Hecks::Utils.block_source(ca.block)}",
         "#{indent}end"]
      end
    end

    def serialize_specifications(specs, indent)
      inner = indent + "  "
      specs.flat_map do |spec|
        params = spec.block&.parameters&.map { |_, n| n.to_s } || []
        param_str = params.empty? ? "|object|" : "|#{params.join(", ")}|"
        ["", "#{indent}specification \"#{spec.name}\" do #{param_str}",
         "#{inner}#{Hecks::Utils.block_source(spec.block)}",
         "#{indent}end"]
      end
    end

    def serialize_references(refs, indent)
      (refs || []).map do |ref|
        role_opt = ref.name.to_s == ref.type.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                                           .gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase ? "" : ", role: \"#{ref.name}\""
        qualified = ref.domain ? "#{ref.domain}::#{ref.type}" : ref.type
        "#{indent}reference_to \"#{qualified}\"#{role_opt}"
      end
    end

    def serialize_commands(commands, indent)
      inner = indent + "  "
      commands.flat_map do |cmd|
        lines = ["", "#{indent}command \"#{cmd.name}\" do"]
        if cmd.emits
          emits_names = Array(cmd.emits)
          lines << "#{inner}emits #{emits_names.map { |n| "\"#{n}\"" }.join(", ")}"
        end
        lines.concat(serialize_attributes(cmd.attributes, inner))
        lines.concat(serialize_references(cmd.references, inner))
        cmd.read_models.each { |rm| lines << "#{inner}read_model \"#{rm.name}\"" }
        cmd.external_systems.each { |ext| lines << "#{inner}external \"#{ext.name}\"" }
        cmd.actors.each { |act| lines << "#{inner}actor \"#{act.name}\"" }
        lines << "#{indent}end"
      end
    end

    def serialize_policies(policies, indent)
      inner = indent + "  "
      policies.flat_map do |pol|
        lines = ["", "#{indent}policy \"#{pol.name}\" do"]
        lines << "#{inner}on \"#{pol.event_name}\""
        lines << "#{inner}trigger \"#{pol.trigger_command}\""
        lines << "#{inner}async true" if pol.async
        lines << "#{inner}condition { |event| #{Hecks::Utils.block_source(pol.condition)} }" if pol.condition
        lines << "#{indent}end"
      end
    end

    def serialize_subscribers(subscribers, indent)
      inner = indent + "  "
      subscribers.flat_map do |sub|
        async_opt = sub.async ? ", async: true" : ""
        lines = ["", "#{indent}on_event \"#{sub.event_name}\"#{async_opt} do |event|"]
        lines << "#{inner}#{Hecks::Utils.block_source(sub.block)}" if sub.block
        lines << "#{indent}end"
      end
    end

    def serialize_domain_policy(pol)
      lines = ["", "  policy \"#{pol.name}\" do"]
      lines << "    on \"#{pol.event_name}\""
      lines << "    trigger \"#{pol.trigger_command}\""
      lines << "    async true" if pol.async
      if pol.attribute_map.any?
        mapping = pol.attribute_map.map { |from, to| "#{from}: :#{to}" }.join(", ")
        lines << "    map #{mapping}"
      end
      lines << "    condition { |event| #{Hecks::Utils.block_source(pol.condition)} }" if pol.condition
      lines << "  end"
      lines
    end

    def dsl_type(attr)
      if attr.list?
        "list_of(\"#{attr.type}\")"
      else
        attr.type.to_s
      end
    end
  end
end
