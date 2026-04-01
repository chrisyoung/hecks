
module Hecks
  module HTTP
    class MultiDomainServer
      # Hecks::HTTP::MultiDomainServer::UIRoutes
      #
      # UI route handlers for the multi-domain web explorer. Renders ERB
      # views for index, show, form, and submit routes, scoped by domain.
      # Extracted from MultiDomainServer to stay under the 200-line limit.
      #
      module UIRoutes
        include HecksTemplating::NamingHelpers
        private

        def serve_ui_route(req, res, entry, sub_path)
          domain = entry[:domain]
          mod = entry[:mod]
          slug = entry[:slug]

          agg = domain.aggregates.find { |a| sub_path.start_with?("/#{plural(a)}") }
          unless agg
            res.status = 404; res.body = "Not found"; return
          end

          safe = domain_constant_name(agg.name)
          klass = mod.const_get(safe)
          p = plural(agg)
          prefix = "/#{slug}"
          remaining = sub_path.sub("/#{p}", "")

          if remaining == "" || remaining == "/"
            serve_index(res, agg, klass, safe, p, prefix)
          elsif remaining == "/show"
            serve_show(req, res, agg, klass, safe, p, prefix)
          elsif remaining =~ /\/(\w+)\/new$/
            serve_form(req, res, agg, klass, safe, p, prefix, $1)
          elsif remaining =~ /\/(\w+)\/submit$/
            serve_submit(req, res, agg, klass, safe, p, prefix, $1)
          else
            res.status = 404; res.body = "Not found"
          end
        end

        def serve_index(res, agg, klass, safe, p, prefix)
          user_attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
          items = klass.all.map do |obj|
            cells = user_attrs.map { |a| obj.send(a.name).to_s }
            { id: obj.id, short_id: obj.id[0..7], show_href: "#{prefix}/#{p}/show?id=#{obj.id}", cells: cells }
          end
          computed = agg.computed_attributes || []
          computed.each do |ca|
            items.each do |item|
              obj = klass.find(item[:id])
              item[:cells] << obj.instance_eval(&ca.block).to_s if obj
            end
          end
          columns = user_attrs.map { |a| { label: humanize(a.name) } }
          computed.each { |ca| columns << { label: "#{humanize(ca.name)} (computed)" } }
          create_cmds = agg.commands.select { |c| c.name.start_with?("Create") }
          buttons = create_cmds.map do |c|
            cm = domain_snake_name(c.name)
            { label: HecksTemplating::UILabelContract.label(c.name), href: "#{prefix}/#{p}/#{cm}/new", allowed: true }
          end
          html = @renderer.render(:index,
            title: "#{safe}s — #{@brand}", brand: @brand, nav_items: @nav,
            aggregate_name: safe, items: items, columns: columns,
            buttons: buttons, row_actions: [])
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def serve_show(req, res, agg, klass, safe, p, prefix)
          obj = klass.find(req.query["id"])
          unless obj
            res.status = 404; res.body = "Not found"; return
          end
          user_attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
          fields = user_attrs.map { |a| { label: humanize(a.name), value: obj.send(a.name).to_s } }
          (agg.computed_attributes || []).each do |ca|
            fields << { label: "#{humanize(ca.name)} (computed)", value: obj.instance_eval(&ca.block).to_s }
          end
          html = @renderer.render(:show,
            title: "#{safe} — #{@brand}", brand: @brand, nav_items: @nav,
            aggregate_name: safe, back_href: "#{prefix}/#{p}",
            id: obj.id, fields: fields, buttons: [])
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def serve_form(req, res, agg, klass, safe, p, prefix, cmd_snake)
          cmd = agg.commands.find { |c| domain_snake_name(c.name) == cmd_snake }
          unless cmd
            res.status = 404; res.body = "Command not found"; return
          end
          fields = cmd.attributes.map do |a|
            { type: :input, name: a.name.to_s, label: humanize(a.name),
              input_type: "text", step: false, required: false, value: req.query[a.name.to_s] || "" }
          end
          html = @renderer.render(:form,
            title: "#{cmd.name} — #{@brand}", brand: @brand, nav_items: @nav,
            command_name: HecksTemplating::UILabelContract.label(cmd.name),
            action: "#{prefix}/#{p}/#{cmd_snake}/submit",
            error_message: nil, fields: fields)
          res["Content-Type"] = "text/html"
          res.body = html
        end

        def serve_submit(req, res, agg, klass, safe, p, prefix, cmd_snake)
          cmd = agg.commands.find { |c| domain_snake_name(c.name) == cmd_snake }
          unless cmd
            res.status = 404; res.body = "Command not found"; return
          end
          mod = klass
          params = req.query
          method_name = domain_command_method(cmd.name, agg.name)
          attrs = cmd.attributes.each_with_object({}) { |a, h| h[a.name] = params[a.name.to_s] || "" }
          result = klass.send(method_name, **attrs)
          id = result.respond_to?(:aggregate) ? result.aggregate.id : result.id
          res.set_redirect(WEBrick::HTTPStatus::SeeOther, "#{prefix}/#{p}/show?id=#{id}")
        rescue => e
          fields = cmd.attributes.map do |a|
            { type: :input, name: a.name.to_s, label: humanize(a.name),
              input_type: "text", step: false, required: false, value: params[a.name.to_s] || "" }
          end
          html = @renderer.render(:form,
            title: "#{cmd.name} — #{@brand}", brand: @brand, nav_items: @nav,
            command_name: HecksTemplating::UILabelContract.label(cmd.name),
            action: "#{prefix}/#{p}/#{cmd_snake}/submit",
            error_message: e.message, fields: fields)
          res["Content-Type"] = "text/html"
          res.body = html
        end
      end
    end
  end
end
