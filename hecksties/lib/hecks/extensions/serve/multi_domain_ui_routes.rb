
module Hecks
  module HTTP
    class MultiDomainServer
      # Hecks::HTTP::MultiDomainServer::UIRoutes
      #
      # UI route handlers for the multi-domain web explorer. Structural
      # discovery (columns, fields, buttons) comes from IRIntrospector.
      # Runtime data access (find, all, execute) goes through RuntimeBridge.
      # Extracted from MultiDomainServer to stay under the 200-line limit.
      #
      module UIRoutes
        include HecksTemplating::NamingHelpers
        include CsrfHelpers
        private

        def serve_ui_route(req, res, entry, sub_path)
          ir = entry[:ir]
          bridge = entry[:bridge]
          slug = entry[:slug]

          agg = ir.domain.aggregates.find { |a| sub_path.start_with?("/#{plural(a)}") }
          unless agg
            res.status = 404; res.body = "Not found"; return
          end

          safe = domain_constant_name(agg.name)
          p = plural(agg)
          prefix = "/#{slug}"
          remaining = sub_path.sub("/#{p}", "")

          if remaining == "" || remaining == "/"
            serve_index(req, res, ir, bridge, agg, safe, p, prefix)
          elsif remaining == "/show"
            serve_show(req, res, ir, bridge, agg, safe, p, prefix)
          elsif remaining =~ /\/(\w+)\/new$/
            serve_form(req, res, ir, agg, safe, p, prefix, $1)
          elsif remaining =~ /\/(\w+)\/submit$/
            serve_submit(req, res, ir, bridge, agg, safe, p, prefix, $1)
          else
            res.status = 404; res.body = "Not found"
          end
        end

        def serve_index(req, res, ir, bridge, agg, safe, p, prefix)
          token = ensure_csrf_cookie(req, res)
          user_attrs = ir.user_attributes(agg)
          search_query = req.query["q"]
          filters = extract_filters(req.query, ir.filterable_attributes(agg))
          searchable_names = user_attrs.map(&:name)

          objects = if filters.any? || (search_query && !search_query.strip.empty?)
            bridge.search_and_filter(agg.name, filters: filters, query: search_query, attributes: searchable_names)
          else
            bridge.find_all(agg.name)
          end

          items = build_index_items(objects, user_attrs, ir, bridge, agg, prefix, p)
          append_computed_cells(items, ir, bridge, agg)
          filter_params = build_filter_query_string(filters, search_query)
          columns = ir.columns_for(agg)
          filterable = ir.filterable_attributes(agg)
          create_cmds = ir.create_commands(agg)
          buttons = create_cmds.map do |c|
            cm = domain_snake_name(c.name)
            { label: HecksTemplating::UILabelContract.label(c.name), href: "#{prefix}/#{p}/#{cm}/new", allowed: true }
          end
          html = @renderer.render(:index,
            title: "#{safe}s — #{@brand}", brand: @brand, nav_items: @nav,
            aggregate_name: safe, items: items, columns: columns,
            buttons: buttons, row_actions: [], csrf_token: token,
            search_query: search_query || "", active_filters: filters,
            filterable_attributes: filterable, filter_params: filter_params)
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def serve_show(req, res, ir, bridge, agg, safe, p, prefix)
          token = ensure_csrf_cookie(req, res)
          obj = bridge.find_by_id(agg.name, req.query["id"])
          unless obj
            res.status = 404; res.body = "Not found"; return
          end
          user_attrs = ir.user_attributes(agg)
          fields = user_attrs.map { |a|
            lbl = ir.field_label(a)
            val = if ir.reference_attr?(a)
              ref_agg = ir.find_referenced_aggregate(a)
              bridge.resolve_reference_display(obj, a, ref_agg&.name)
            else
              bridge.read_attribute(obj, a.name)
            end
            { label: lbl, value: val }
          }
          ir.computed_attributes(agg).each do |ca|
            fields << { label: "#{Hecks::Utils.humanize(Hecks::Utils.sanitize_constant(ca.name))} (computed)",
                        value: bridge.evaluate_computed(obj, ca.block) }
          end
          html = @renderer.render(:show,
            title: "#{safe} — #{@brand}", brand: @brand, nav_items: @nav,
            aggregate_name: safe, back_href: "#{prefix}/#{p}",
            id: bridge.read_id(obj), fields: fields, buttons: [], csrf_token: token)
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def serve_form(req, res, ir, agg, safe, p, prefix, cmd_snake)
          token = ensure_csrf_cookie(req, res)
          cmd = ir.find_command(agg, cmd_snake)
          unless cmd
            res.status = 404; res.body = "Command not found"; return
          end
          fields = ir.command_fields(cmd, req.query)
          html = @renderer.render(:form,
            title: "#{cmd.name} — #{@brand}", brand: @brand, nav_items: @nav,
            command_name: HecksTemplating::UILabelContract.label(cmd.name),
            action: "#{prefix}/#{p}/#{cmd_snake}/submit",
            error_message: nil, fields: fields, csrf_token: token)
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def serve_submit(req, res, ir, bridge, agg, safe, p, prefix, cmd_snake)
          unless valid_csrf?(req)
            res.status = 403; res.body = "Forbidden: CSRF token mismatch"; return
          end
          cmd = ir.find_command(agg, cmd_snake)
          unless cmd
            res.status = 404; res.body = "Command not found"; return
          end
          params = req.query
          method_name = domain_command_method(cmd.name, agg.name)
          attrs = cmd.attributes.each_with_object({}) { |a, h| h[a.name] = params[a.name.to_s] || "" }
          id = bridge.execute_command(agg.name, method_name, attrs)
          res.set_redirect(WEBrick::HTTPStatus::SeeOther, "#{prefix}/#{p}/show?id=#{id}")
        rescue => e
          token = read_csrf_cookie(req)
          fields = ir.command_fields(cmd, params || {})
          html = @renderer.render(:form,
            title: "#{cmd.name} — #{@brand}", brand: @brand, nav_items: @nav,
            command_name: HecksTemplating::UILabelContract.label(cmd.name),
            action: "#{prefix}/#{p}/#{cmd_snake}/submit",
            error_message: e.message, fields: fields, csrf_token: token)
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def valid_csrf?(req)
          return true if token_authenticated?(req)
          cookie_val = read_csrf_cookie(req)
          form_val = req.query[Hecks::Conventions::CsrfContract::FIELD_NAME]
          Hecks::Conventions::CsrfContract.valid?(cookie_val, form_val)
        end

        def extract_filters(query_params, filterable_attrs)
          allowed = filterable_attrs.map { |a| a.name.to_s }
          query_params.each_with_object({}) do |(key, val), h|
            next unless key.start_with?("filter[") && key.end_with?("]")
            attr_name = key[7..-2]
            h[attr_name.to_sym] = val if allowed.include?(attr_name) && !val.to_s.strip.empty?
          end
        end

        def build_index_items(objects, user_attrs, ir, bridge, agg, prefix, p)
          objects.map do |obj|
            cells = user_attrs.map { |a|
              if ir.reference_attr?(a)
                ref_agg = ir.find_referenced_aggregate(a)
                bridge.resolve_reference_display(obj, a, ref_agg&.name)
              else
                bridge.read_attribute(obj, a.name)
              end
            }
            id = bridge.read_id(obj)
            { id: id, short_id: id[0..7], show_href: "#{prefix}/#{p}/show?id=#{id}", cells: cells }
          end
        end

        def append_computed_cells(items, ir, bridge, agg)
          ir.computed_attributes(agg).each do |ca|
            items.each do |item|
              obj = bridge.find_by_id(agg.name, item[:id])
              item[:cells] << bridge.evaluate_computed(obj, ca.block) if obj
            end
          end
        end

        def build_filter_query_string(filters, search_query)
          parts = []
          filters.each { |k, v| parts << "filter[#{k}]=#{ERB::Util.url_encode(v)}" }
          parts << "q=#{ERB::Util.url_encode(search_query)}" if search_query && !search_query.strip.empty?
          parts.empty? ? "" : "&#{parts.join("&")}"
        end
      end
    end
  end
end
