# HecksStatic::UIGenerator::FormRoutes
#
# Generates form and submit routes for commands. Handles self-referencing
# hidden fields, cross-aggregate dropdowns, role enforcement, validation
# error re-rendering, and type coercion.
#
module HecksStatic
  class UIGenerator
    module FormRoutes
      private

      def new_routes(agg, mod)
        safe = Hecks::Utils.sanitize_constant(agg.name)
        p = plural(agg)
        lines = []

        agg.commands.each do |cmd|
          cmd_snake = Hecks::Utils.underscore(cmd.name)
          agg_snake = Hecks::Utils.underscore(agg.name)
          self_id_attr = cmd.attributes.find { |a| a.name.to_s == "#{agg_snake}_id" }

          lines << "        server.mount_proc \"/#{p}/#{cmd_snake}/new\" do |req, res|"
          field_parts = build_form_fields(cmd, agg, self_id_attr)
          form_fields = field_parts.join(" + ")

          lines << "          unless #{mod}.role_allows?(\"#{safe}\", \"#{cmd_snake}\")"
          lines << "            html_response(res, layout(title: \"Denied — #{mod}\", nav_items: nav) {"
          lines << "              \"<div class='flash flash-error'>Role '\" + #{mod}.current_role.to_s + \"' cannot #{cmd_snake}</div><a href='/#{p}' class='btn'>Back</a>\""
          lines << "            }); next"
          lines << "          end"
          lines << "          html_response(res, layout(title: \"#{cmd.name} — #{mod}\", nav_items: nav) {"
          lines << "            \"<h1>#{cmd.name}</h1><form method='post' action='/#{p}/#{cmd_snake}/submit'>\" + #{form_fields} + \"<button class='btn' type='submit'>#{cmd.name}</button></form>\""
          lines << "          })"
          lines << "        end"
          lines << ""

          lines.concat(submit_route(cmd, agg, mod, safe, p, cmd_snake))
        end
        lines
      end

      def build_form_fields(cmd, agg, self_id_attr)
        field_parts = []
        cmd.attributes.each do |a|
          if a == self_id_attr
            field_parts << "\"<input type='hidden' name='#{a.name}' value='\" + h(req.query[\"id\"] || \"\") + \"'>\""
          elsif a.name.to_s.end_with?("_id")
            field_parts << ref_dropdown_field(a, agg)
          else
            field_parts << text_input_field(a, agg)
          end
        end
        field_parts
      end

      def ref_dropdown_field(a, agg)
        ref_name = a.name.to_s.sub(/_id$/, "")
        ref_found = @domain.aggregates.find { |ra| Hecks::Utils.underscore(ra.name) == ref_name }
        if ref_found
          ref_const = Hecks::Utils.sanitize_constant(ref_found.name)
          ref_safe = ref_name.split("_").map(&:capitalize).join
          display_attr = ref_found.attributes.find { |da| da.name.to_s == "name" } ||
                         ref_found.attributes.find { |da| da.name.to_s == "title" } ||
                         ref_found.attributes.reject { |da| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(da.name.to_s) }.first
          display_method = display_attr ? display_attr.name.to_s : "id"
          hint = required_hint(agg, a.name)
          "\"<label>#{ref_safe}#{hint}</label><select name='#{a.name}' required>\" + " \
            "#{ref_const}.all.map { |r| selected = r.id == req.query[\"id\"] ? \" selected\" : \"\"; " \
            "\"<option value='\" + r.id + \"'\" + selected + \">\" + r.#{display_method}.to_s + \"</option>\" }.join + \"</select>\""
        else
          hint = required_hint(agg, a.name)
          label = a.name.to_s.split("_").map(&:capitalize).join(" ")
          "\"<label>#{label}#{hint}</label><input name='#{a.name}' type='text' required>\""
        end
      end

      def text_input_field(a, agg)
        type = case a.type.to_s
               when /Integer/ then "number"
               when /Float/ then "number"
               else "text"
               end
        step = a.type.to_s =~ /Float/ ? " step='any'" : ""
        hint = required_hint(agg, a.name)
        label = a.name.to_s.split("_").map(&:capitalize).join(" ")
        "\"<label>#{label}#{hint}</label><input name='#{a.name}' type='#{type}'#{step} required>\""
      end

      def submit_route(cmd, agg, mod, safe, p, cmd_snake)
        lines = []
        lines << "        server.mount_proc \"/#{p}/#{cmd_snake}/submit\" do |req, res|"
        lines << "          unless #{mod}.role_allows?(\"#{safe}\", \"#{cmd_snake}\")"
        lines << "            res.status = 403; html_response(res, \"Forbidden\"); next"
        lines << "          end"
        lines << "          begin"
        lines << "            params = req.query"
        coerce_lines = cmd.attributes.map do |a|
          val = case a.type.to_s
                when /Integer/ then "params[\"#{a.name}\"].to_i"
                when /Float/ then "params[\"#{a.name}\"].to_f"
                else "params[\"#{a.name}\"]"
                end
          "#{a.name}: #{val}"
        end
        lines << "            result = #{safe}.#{cmd_snake}(#{coerce_lines.join(", ")})"
        lines << "            res.set_redirect(WEBrick::HTTPStatus::SeeOther, \"/#{p}/show?id=\" + result.aggregate.id)"
        lines << "          rescue #{@domain.module_name}Domain::ValidationError => e"
        lines << "            error_field = e.respond_to?(:field) ? e.field.to_s : nil"
        lines << "            error_html = error_field ? \"\" : \"<div class='flash flash-error'>\" + h(e.message) + \"</div>\""
        rerender_parts = build_rerender_fields(cmd, agg)
        form_rerender = rerender_parts.join(" + ")
        lines << "            html_response(res, layout(title: \"#{cmd.name} — #{mod}\", nav_items: nav) {"
        lines << "              \"<h1>#{cmd.name}</h1>\" + error_html + \"<form method='post' action='/#{p}/#{cmd_snake}/submit'>\" + #{form_rerender} + \"<button class='btn' type='submit'>#{cmd.name}</button></form>\""
        lines << "            })"
        lines << "          rescue #{@domain.module_name}Domain::Error => e"
        lines << "            html_response(res, layout(title: \"Error — #{mod}\", nav_items: nav) {"
        lines << "              \"<div class='flash flash-error'>\" + h(e.message) + \"</div><a href='/#{p}/#{cmd_snake}/new' class='btn'>Try again</a>\""
        lines << "            })"
        lines << "          end"
        lines << "        end"
        lines << ""
        lines
      end

      def build_rerender_fields(cmd, agg)
        parts = []
        cmd.attributes.each do |a|
          agg_s = Hecks::Utils.underscore(agg.name)
          label = a.name.to_s.split("_").map(&:capitalize).join(" ")
          val_expr = "params[\"#{a.name}\"]"
          error_div = "(error_field == \"#{a.name}\" ? \"<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>\" + h(e.message) + \"</div>\" : \"\")"

          if a.name.to_s == "#{agg_s}_id"
            parts << "\"<input type='hidden' name='#{a.name}' value='\" + h(#{val_expr} || \"\") + \"'>\""
          elsif a.name.to_s.end_with?("_id")
            ref_name = a.name.to_s.sub(/_id$/, "")
            ref_agg = @domain.aggregates.find { |ra| Hecks::Utils.underscore(ra.name) == ref_name }
            if ref_agg
              ref_const = Hecks::Utils.sanitize_constant(ref_agg.name)
              display = ref_agg.attributes.find { |da| da.name.to_s == "name" } ? "name" : "id"
              parts << "\"<label>#{label}</label><select name='#{a.name}' required>\" + #{ref_const}.all.map { |r| sel = r.id == #{val_expr} ? \" selected\" : \"\"; \"<option value='\" + r.id + \"'\" + sel + \">\" + r.#{display}.to_s + \"</option>\" }.join + \"</select>\" + #{error_div}"
            else
              parts << "\"<label>#{label}</label><input name='#{a.name}' type='text' value='\" + h(#{val_expr} || \"\") + \"' required>\" + #{error_div}"
            end
          else
            type = case a.type.to_s
                   when /Integer/ then "number"
                   when /Float/ then "number"
                   else "text"
                   end
            parts << "\"<label>#{label}</label><input name='#{a.name}' type='#{type}' value='\" + h(#{val_expr} || \"\") + \"' required>\" + #{error_div}"
          end
        end
        parts
      end
    end
  end
end
