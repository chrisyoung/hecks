# HecksStatic::UIGenerator::DataRoutes
#
# Generates index and show route handlers. Includes reference columns
# (from agg.references) in both index table and show field lists so that
# foreign-key relationships appear with clean labels like "Pizza"
# instead of raw "_id" field names.
#
module HecksStatic
  class UIGenerator < Hecks::Generator
    module DataRoutes
      include HecksTemplating::NamingHelpers
      private

      def index_route(agg, mod)
        safe = domain_constant_name(agg.name)
        p = plural(agg)
        attrs = user_attrs(agg)
        agg_snake = domain_snake_name(agg.name)
        ac = HecksTemplating::AggregateContract
        dc = HecksTemplating::DisplayContract
        create_cmds, update_cmds = ac.partition_commands(agg)

        refs = agg.references || []
        ref_columns = refs.map { |r| "{ label: \"#{dc.reference_column_label(r)}\" }" }
        columns = attrs.map { |a| "{ label: \"#{humanize(a.name)}\" }" } + ref_columns
        btns = create_cmds.map { |c|
          cm = domain_snake_name(c.name)
          "{ label: \"#{HecksTemplating::UILabelContract.label(c.name)}\", href: \"/#{p}/#{cm}/new\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }"
        }
        row_acts = update_cmds.map do |c|
          cm = domain_snake_name(c.name)
          if ac.direct_action?(c, agg_snake)
            self_id = ac.self_ref_attr(c, agg_snake)
            "{ label: \"#{HecksTemplating::UILabelContract.label(c.name)}\", href_prefix: \"/#{p}/#{cm}/submit\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\"), direct: true, id_field: \"#{self_id&.name}\" }"
          else
            "{ label: \"#{HecksTemplating::UILabelContract.label(c.name)}\", href_prefix: \"/#{p}/#{cm}/new?id=\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }"
          end
        end

        cell_exprs = attrs.map { |a| dc.cell_expression(a, "obj", lang: :ruby) }
        ref_cell_exprs = refs.map { |r|
          field = dc.strip_id_suffix(r.name)
          "obj.respond_to?(:#{field}) ? obj.#{field}.to_s : \"\""
        }
        cells_code = (cell_exprs + ref_cell_exprs).join(", ")

        [
          "        server.mount_proc \"/#{p}\" do |req, res|",
          "          next unless req.path == \"/#{p}\"",
          "          all_items = #{safe}.all",
          "          items = all_items.map { |obj| { id: obj.id, short_id: #{HecksTemplating::ViewContract.ruby_short_id('obj.id')}, show_href: \"/#{p}/show?id=\" + obj.id, cells: [#{cells_code}] } }",
          "          html = renderer.render(:index, title: \"#{safe}s — #{mod}\", brand: brand, nav_items: nav,",
          "            aggregate_name: \"#{safe}\", items: items,",
          "            columns: [#{columns.join(', ')}],",
          "            buttons: [#{btns.join(', ')}],",
          "            row_actions: [#{row_acts.join(', ')}])",
          "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
          "        end",
          ""
        ]
      end

      def show_route(agg, mod)
        safe = domain_constant_name(agg.name)
        p = plural(agg)
        attrs = user_attrs(agg)
        agg_snake = domain_snake_name(agg.name)
        ac = HecksTemplating::AggregateContract
        dc = HecksTemplating::DisplayContract

        lc = agg.lifecycle
        lc_field = lc&.field&.to_s
        field_exprs = build_attr_field_exprs(attrs, agg, lc, lc_field, dc) +
                      build_ref_field_exprs(agg.references || [], dc)

        btn_parts = build_show_buttons(agg, agg_snake, p, safe, mod, ac)

        [
          "        server.mount_proc \"/#{p}/show\" do |req, res|",
          "          obj = #{safe}.find(req.query[\"id\"])",
          "          unless obj",
          "            res.status = 404; res.body = \"Not found\"; next",
          "          end",
          "          html = renderer.render(:show, title: \"#{safe} — #{mod}\", brand: brand, nav_items: nav,",
          "            aggregate_name: \"#{safe}\", back_href: \"/#{p}\",",
          "            id: obj.id, fields: [#{field_exprs.join(', ')}],",
          "            buttons: [#{btn_parts.join(', ')}])",
          "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
          "        end",
          ""
        ]
      end

      def build_attr_field_exprs(attrs, agg, lc, lc_field, dc)
        attrs.map do |a|
          if a.list?
            vo = agg.value_objects.find { |v| v.name == a.type.to_s }
            if vo
              vo_attrs = vo.attributes.map(&:name).map(&:to_s)
              items_expr = "obj.#{a.name}.map { |v| #{vo_attrs.map { |va| "v.#{va}.to_s" }.join(' + " — " + ')} }"
              "{ label: \"#{humanize(a.name)}\", type: :list, items: #{items_expr} }"
            else
              "{ label: \"#{humanize(a.name)}\", type: :list, items: obj.#{a.name}.map(&:to_s) }"
            end
          elsif lc_field && a.name.to_s == lc_field
            transitions = HecksTemplating::DisplayContract.lifecycle_transitions(lc)
            "{ label: \"#{humanize(a.name)}\", type: :lifecycle, value: obj.#{a.name}.to_s, transitions: #{transitions.inspect} }"
          else
            "{ label: \"#{humanize(a.name)}\", value: obj.#{a.name}.to_s }"
          end
        end
      end

      def build_ref_field_exprs(refs, dc)
        refs.map do |r|
          label = dc.reference_column_label(r)
          field = dc.strip_id_suffix(r.name)
          "{ label: \"#{label}\", value: obj.respond_to?(:#{field}) ? obj.#{field}.to_s : \"\" }"
        end
      end

      def build_show_buttons(agg, agg_snake, p, safe, mod, ac)
        _, update_cmds = ac.partition_commands(agg)
        btn_parts = update_cmds.map do |c|
          cm = domain_snake_name(c.name)
          if ac.direct_action?(c, agg_snake)
            self_id = ac.self_ref_attr(c, agg_snake)
            "{ label: \"#{HecksTemplating::UILabelContract.label(c.name)}\", href: \"/#{p}/#{cm}/submit\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\"), direct: true, id_field: \"#{self_id.name}\" }"
          else
            "{ label: \"#{HecksTemplating::UILabelContract.label(c.name)}\", href: \"/#{p}/#{cm}/new?id=\" + obj.id, allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }"
          end
        end
        snake = domain_snake_name(agg.name)
        @domain.aggregates.each do |other|
          next if other.name == agg.name
          other_safe = domain_constant_name(other.name)
          other_p = plural(other)
          other.commands.each do |cmd|
            next unless cmd.attributes.any? { |a| a.name.to_s == "#{snake}_id" }
            cm = domain_snake_name(cmd.name)
            btn_parts << "{ label: \"#{HecksTemplating::UILabelContract.label(cmd.name)}\", href: \"/#{other_p}/#{cm}/new?id=\" + obj.id, allowed: #{mod}.role_allows?(\"#{other_safe}\", \"#{cm}\") }"
          end
        end
        btn_parts
      end
    end
  end
end
