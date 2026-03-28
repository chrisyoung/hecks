# HecksStatic::UIGenerator::FormRoutes
#
# Generates form and submit route handlers. Prepares field data hashes
# and renders via the ERB renderer. Handles role enforcement, type
# coercion, and validation error re-rendering.
#
module HecksStatic
  class UIGenerator
    module FormRoutes
      private

      def new_routes(agg, mod)
        safe = Hecks::Utils.sanitize_constant(agg.name)
        p = plural(agg)
        agg_snake = Hecks::Utils.underscore(agg.name)
        lines = []

        agg.commands.each do |cmd|
          cmd_snake = Hecks::Utils.underscore(cmd.name)
          self_id_attr = Hecks::AggregateContract.self_ref_attr(cmd, agg_snake)

          # Build field descriptors
          field_descriptors = cmd.attributes.map { |a| field_descriptor(a, agg, self_id_attr) }

          # Form GET
          lines << "        server.mount_proc \"/#{p}/#{cmd_snake}/new\" do |req, res|"
          lines << "          unless #{mod}.role_allows?(\"#{safe}\", \"#{cmd_snake}\")"
          lines << "            html = renderer.render(:form, title: \"Denied — #{mod}\", brand: brand, nav_items: nav,"
          lines << "              command_name: \"#{cmd.name}\", action: \"\", error_message: \"Role '\" + #{mod}.current_role.to_s + \"' cannot #{cmd_snake}\", fields: [])"
          lines << "            res[\"Content-Type\"] = \"text/html\"; res.body = html; next"
          lines << "          end"
          lines << "          fields = #{build_fields_code(cmd, agg, self_id_attr)}"
          lines << "          html = renderer.render(:form, title: \"#{cmd.name} — #{mod}\", brand: brand, nav_items: nav,"
          lines << "            command_name: \"#{cmd.name}\", action: \"/#{p}/#{cmd_snake}/submit\", error_message: nil, fields: fields)"
          lines << "          res[\"Content-Type\"] = \"text/html\"; res.body = html"
          lines << "        end"
          lines << ""

          # Submit POST
          lines.concat(submit_route(cmd, agg, mod, safe, p, cmd_snake, self_id_attr))
        end
        lines
      end

      def field_descriptor(attr, agg, self_id_attr)
        agg_snake = Hecks::Utils.underscore(agg.name)
        if attr == self_id_attr
          { type: :hidden, name: attr.name.to_s }
        elsif attr.name.to_s.end_with?("_id")
          # Find referenced aggregate: explicit reference_to or name convention
          ref_agg = if attr.reference?
            @domain.aggregates.find { |ra| ra.name == attr.type.to_s }
          else
            ref_name = attr.name.to_s.sub(/_id$/, "")
            @domain.aggregates.find { |ra| Hecks::Utils.underscore(ra.name) == ref_name }
          end
          if ref_agg
            display = Hecks::DisplayContract.reference_display_field(ref_agg)
            { type: :select, name: attr.name.to_s, ref: Hecks::Utils.sanitize_constant(ref_agg.name),
              label: humanize(attr.name.to_s.sub(/_id$/, "")), required: required_field?(agg, attr.name),
              display: display }
          else
            { type: :text, name: attr.name.to_s, label: humanize(attr.name), required: required_field?(agg, attr.name) }
          end
        else
          # Check if the aggregate attribute has an enum
          agg_attr = agg.attributes.find { |aa| aa.name == attr.name }
          enum_values = agg_attr&.enum
          if enum_values && !enum_values.empty?
            { type: :enum, name: attr.name.to_s, label: humanize(attr.name),
              options: enum_values, required: required_field?(agg, attr.name) }
          else
            go_type = Hecks::TypeContract.go(attr.type)
            input_type = Hecks::FormParsingContract.input_type(go_type)
            step = Hecks::FormParsingContract.step?(go_type)
            { type: :input, name: attr.name.to_s, label: humanize(attr.name),
              input_type: input_type, step: step,
              required: required_field?(agg, attr.name) }
          end
        end
      end

      def build_fields_code(cmd, agg, self_id_attr)
        parts = cmd.attributes.map do |a|
          desc = field_descriptor(a, agg, self_id_attr)
          case desc[:type]
          when :hidden
            "{ type: :hidden, name: \"#{desc[:name]}\", value: req.query[\"id\"] || \"\" }"
          when :select
            "{ type: :select, name: \"#{desc[:name]}\", label: \"#{desc[:label]}\", required: #{desc[:required]}," \
            " options: #{desc[:ref]}.all.map { |r| { value: r.id, label: r.#{desc[:display]}.to_s, selected: r.id == req.query[\"id\"] } } }"
          else
            "{ type: :input, name: \"#{desc[:name]}\", label: \"#{desc[:label]}\", input_type: \"#{desc[:input_type]}\"," \
            " step: #{desc[:step] ? true : false}, required: #{desc[:required]}, value: \"\" }"
          end
        end
        "[#{parts.join(', ')}]"
      end

      def submit_route(cmd, agg, mod, safe, p, cmd_snake, self_id_attr)
        lines = []
        lines << "        server.mount_proc \"/#{p}/#{cmd_snake}/submit\" do |req, res|"
        lines << "          unless #{mod}.role_allows?(\"#{safe}\", \"#{cmd_snake}\")"
        lines << "            res.status = 403; res.body = \"Forbidden\"; next"
        lines << "          end"
        lines << "          begin"
        lines << "            params = req.query"
        coerce_lines = cmd.attributes.map do |a|
          val = Hecks::FormParsingContract.ruby_coerce(a.name, a.type.to_s)
          "#{a.name}: #{val}"
        end
        lines << "            result = #{safe}.#{cmd_snake}(#{coerce_lines.join(", ")})"
        lines << "            res.set_redirect(WEBrick::HTTPStatus::SeeOther, \"/#{p}/show?id=\" + result.aggregate.id)"
        lines << "          rescue #{@domain.module_name}Domain::ValidationError => e"
        lines << "            fields = #{build_fields_code(cmd, agg, self_id_attr)}"
        lines << "            fields.each { |f| f[:value] = params[f[:name]] || f[:value] if f[:type] != :hidden }"
        lines << "            fields.each { |f| f[:error] = e.message if e.respond_to?(:field) && e.field.to_s == f[:name] }"
        lines << "            html = renderer.render(:form, title: \"#{cmd.name} — #{mod}\", brand: brand, nav_items: nav,"
        lines << "              command_name: \"#{cmd.name}\", action: \"/#{p}/#{cmd_snake}/submit\","
        lines << "              error_message: (e.respond_to?(:field) && e.field ? nil : e.message), fields: fields)"
        lines << "            res[\"Content-Type\"] = \"text/html\"; res.body = html"
        lines << "          rescue #{@domain.module_name}Domain::Error => e"
        lines << "            html = renderer.render(:form, title: \"Error — #{mod}\", brand: brand, nav_items: nav,"
        lines << "              command_name: \"#{cmd.name}\", action: \"/#{p}/#{cmd_snake}/new\","
        lines << "              error_message: e.message, fields: [])"
        lines << "            res[\"Content-Type\"] = \"text/html\"; res.body = html"
        lines << "          end"
        lines << "        end"
        lines << ""
        lines
      end
    end
  end
end
