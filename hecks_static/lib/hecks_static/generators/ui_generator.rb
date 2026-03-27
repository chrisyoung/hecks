module HecksStatic
# Hecks::Generators::Standalone::UIGenerator
#
# Generates HTML routes for each aggregate: index (table), show (detail),
# and new (form per create command). Produces a Ruby file that mounts
# WEBrick routes alongside the JSON API. No template engine — just strings.
#
#   gen = UIGenerator.new(domain)
#   gen.generate("PizzasDomain", "pizzas_domain")
#
class UIGenerator
  def initialize(domain)
    @domain = domain
  end

  def generate(mod, gem_name)
    lines = []
    lines << "require_relative \"ui\""
    lines << ""
    lines << "module #{mod}"
    lines << "  module Server"
    lines << "    module UIRoutes"
    lines << "      include UI"
    lines << ""
    lines << "      def mount_ui_routes(server)"
    lines << "        nav = #{nav_items.inspect}"
    lines << ""
    lines.concat(root_route(mod))
    @domain.aggregates.each { |agg| lines.concat(index_route(agg, mod)) }
    @domain.aggregates.each { |agg| lines.concat(show_route(agg, mod)) }
    @domain.aggregates.each { |agg| lines.concat(new_routes(agg, mod)) }
    lines.concat(config_route(mod))
    lines.concat(reboot_route(mod))
    lines << "      end"
    lines << "    end"
    lines << "  end"
    lines << "end"
    lines.join("\n") + "\n"
  end

  private

  def nav_items
    items = [{ label: "Home", href: "/" }]
    @domain.aggregates.each do |agg|
      items << { label: agg.name + "s", href: "/#{plural(agg)}" }
    end
    items << { label: "Config", href: "/config" }
    items
  end

  def plural(agg)
    s = Hecks::Utils.underscore(agg.name)
    s.end_with?("s") ? s : s + "s"
  end

  def user_attrs(agg)
    agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
  end

  # True if the command has an _id attr referencing its own aggregate (update command).
  def self_ref?(cmd, agg_snake)
    cmd.attributes.any? { |a| a.name.to_s == "#{agg_snake}_id" }
  end

  # Check if a field has a presence validation on its aggregate or is a VO attribute
  def required_field?(agg, attr_name)
    return true if agg.validations.any? { |v| v.field.to_s == attr_name.to_s && v.rules[:presence] }
    agg.value_objects.any? { |vo| vo.attributes.any? { |va| va.name.to_s == attr_name.to_s } }
  end

  def required_hint(agg, attr_name)
    required_field?(agg, attr_name) ? "<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span>" : ""
  end

  def root_route(mod)
    cards = @domain.aggregates.map do |agg|
      safe = Hecks::Utils.sanitize_constant(agg.name)
      p = plural(agg)
      "<a href='/#{p}' style='text-decoration:none'>" \
      "<div style='background:#fff;padding:1.5rem;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,0.1)'>" \
      "<h2>#{safe}s</h2><p class='mono'>#{agg.commands.size} commands · #{user_attrs(agg).size} attributes</p>" \
      "</div></a>"
    end
    [
      "        server.mount_proc \"/\" do |req, res|",
      "          next unless req.path == \"/\"",
      "          html_response(res, layout(title: \"#{mod}\", nav_items: nav) {",
      "            \"<h1>#{mod}</h1><div style='display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:1rem'>#{cards.join}</div>\"",
      "          })",
      "        end",
      ""
    ]
  end

  def index_route(agg, mod)
    safe = Hecks::Utils.sanitize_constant(agg.name)
    p = plural(agg)
    attrs = user_attrs(agg)

    agg_snake = Hecks::Utils.underscore(agg.name)
    create_cmds = agg.commands.reject { |c| self_ref?(c, agg_snake) }
    update_cmds = agg.commands.select { |c| self_ref?(c, agg_snake) }

    # Top buttons — always visible, styled by role access
    top_btn_parts = create_cmds.map do |c|
      cmd_method = Hecks::Utils.underscore(c.name)
      "(#{mod}.role_allows?(\"#{safe}\", \"#{cmd_method}\") ? \"<a class='btn' href='/#{p}/#{cmd_method}/new'>#{c.name}</a> \" : \"<a class='btn' href='/#{p}/#{cmd_method}/new' style='opacity:0.4'>#{c.name}</a> \")"
    end
    top_btns_expr = top_btn_parts.empty? ? '""' : top_btn_parts.join(" + ")

    headers = (["ID"] + attrs.map { |a| a.name.to_s.split("_").map(&:capitalize).join(" ") })
    headers << "Actions" unless update_cmds.empty?
    headers_html = headers.map { |h| "<th>#{h}</th>" }.join

    row_cells = "\"<td class='mono'><a href='/#{p}/show?id=\" + obj.id + \"'>\" + h(obj.id[0..7]) + \"...</a></td>\""
    attrs.each do |a|
      if a.list?
        row_cells += " + \"<td>\" + obj.#{a.name}.size.to_s + \" items</td>\""
      else
        row_cells += " + \"<td>\" + h(obj.#{a.name}) + \"</td>\""
      end
    end
    unless update_cmds.empty?
      action_parts = update_cmds.map do |c|
        cmd_method = Hecks::Utils.underscore(c.name)
        "(#{mod}.role_allows?(\"#{safe}\", \"#{cmd_method}\") ? \"<a class='btn btn-sm' href='/#{p}/#{cmd_method}/new?id=\" + obj.id + \"'>#{c.name}</a> \" : \"<a class='btn btn-sm' href='/#{p}/#{cmd_method}/new?id=\" + obj.id + \"' style='opacity:0.4'>#{c.name}</a> \")"
      end
      row_cells += " + \"<td>\" + #{action_parts.join(' + ')} + \"</td>\""
    end

    [
      "        server.mount_proc \"/#{p}\" do |req, res|",
      "          next unless req.path == \"/#{p}\"",
      "          items = #{safe}.all",
      "          rows = items.map { |obj| \"<tr>\" + #{row_cells} + \"</tr>\" }.join",
      "          html_response(res, layout(title: \"#{safe}s — #{mod}\", nav_items: nav) {",
      "            \"<div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem'><h1>#{safe}s (\" + items.size.to_s + \")</h1><div>\" + #{top_btns_expr} + \"</div></div>\" \\",
      "            \"<table><thead><tr>#{headers_html}</tr></thead><tbody>\" + rows + \"</tbody></table>\"",
      "          })",
      "        end",
      ""
    ]
  end

  def show_route(agg, mod)
    safe = Hecks::Utils.sanitize_constant(agg.name)
    p = plural(agg)
    attrs = user_attrs(agg)

    detail_items = attrs.map do |a|
      if a.list?
        vo = agg.value_objects.find { |v| v.name == a.type.to_s }
        if vo
          vo_attrs = vo.attributes.map(&:name).map(&:to_s)
          "\"<dt>#{a.name}</dt><dd>\" + (obj.#{a.name}.empty? ? \"(none)\" : \"<ul>\" + obj.#{a.name}.map { |v| \"<li>\" + #{vo_attrs.map { |va| "v.#{va}.to_s" }.join(' + " — " + ')} + \"</li>\" }.join + \"</ul>\") + \"</dd>\""
        else
          "\"<dt>#{a.name}</dt><dd>\" + obj.#{a.name}.size.to_s + \" items</dd>\""
        end
      else
        "\"<dt>#{a.name}</dt><dd>\" + h(obj.#{a.name}) + \"</dd>\""
      end
    end
    detail_expr = detail_items.join(" + ")
    detail_expr = '""' if detail_items.empty?

    # Buttons for update commands on this aggregate (self-referencing _id only)
    agg_snake = Hecks::Utils.underscore(agg.name)
    update_cmds = agg.commands.select { |c| self_ref?(c, agg_snake) }
    update_btns = update_cmds.map do |c|
      cm = Hecks::Utils.underscore(c.name)
      "(#{mod}.role_allows?(\"#{safe}\", \"#{cm}\") ? \"<a class='btn btn-sm' href='/#{p}/#{cm}/new?id=\" + obj.id + \"'>#{c.name}</a> \" : \"<a class='btn btn-sm' href='/#{p}/#{cm}/new?id=\" + obj.id + \"' style='opacity:0.4'>#{c.name}</a> \")"
    end

    # Buttons for commands on OTHER aggregates that reference this one
    snake = Hecks::Utils.underscore(agg.name)
    @domain.aggregates.each do |other_agg|
      next if other_agg.name == agg.name
      other_safe = Hecks::Utils.sanitize_constant(other_agg.name)
      other_p = plural(other_agg)
      other_agg.commands.each do |cmd|
        ref_attr = cmd.attributes.find { |a| a.name.to_s == "#{snake}_id" }
        next unless ref_attr
        cm = Hecks::Utils.underscore(cmd.name)
        update_btns << "(#{mod}.role_allows?(\"#{other_safe}\", \"#{cm}\") ? \"<a class='btn btn-sm' href='/#{other_p}/#{cm}/new?id=\" + obj.id + \"'>#{cmd.name}</a> \" : \"<a class='btn btn-sm' href='/#{other_p}/#{cm}/new?id=\" + obj.id + \"' style='opacity:0.4'>#{cmd.name}</a> \")"
      end
    end

    btns_expr = update_btns.empty? ? '""' : update_btns.join(' + ')

    [
      "        server.mount_proc \"/#{p}/show\" do |req, res|",
      "          obj = #{safe}.find(req.query[\"id\"])",
      "          unless obj",
      "            res.status = 404; html_response(res, \"Not found\"); next",
      "          end",
      "          html_response(res, layout(title: \"#{safe} — #{mod}\", nav_items: nav) {",
      "            \"<h1>#{safe}</h1><div class='detail'><dl><dt>ID</dt><dd class='mono'>\" + h(obj.id) + \"</dd>\" + #{detail_expr} + \"</dl></div>\" \\",
      "            \"<div class='actions'><a href='/#{p}' class='btn btn-sm'>Back</a> \" + #{btns_expr} + \"</div>\"",
      "          })",
      "        end",
      ""
    ]
  end

  def new_routes(agg, mod)
    safe = Hecks::Utils.sanitize_constant(agg.name)
    p = plural(agg)
    lines = []

    agg.commands.each do |cmd|
      cmd_snake = Hecks::Utils.underscore(cmd.name)
      agg_snake = Hecks::Utils.underscore(agg.name)
      self_id_attr = cmd.attributes.find { |a| a.name.to_s == "#{agg_snake}_id" }

      lines << "        server.mount_proc \"/#{p}/#{cmd_snake}/new\" do |req, res|"

      # Build form fields dynamically
      field_parts = []
      cmd.attributes.each do |a|
        if a == self_id_attr
          # Self-reference: hidden field pre-filled from query param
          field_parts << "\"<input type='hidden' name='#{a.name}' value='\" + h(req.query[\"id\"] || \"\") + \"'>\""
        elsif a.name.to_s.end_with?("_id")
          # Cross-aggregate reference: dropdown populated from that aggregate's records
          ref_name = a.name.to_s.sub(/_id$/, "")
          ref_safe = ref_name.split("_").map(&:capitalize).join
          ref_found = @domain.aggregates.find { |ra| Hecks::Utils.underscore(ra.name) == ref_name }
          if ref_found
            ref_const = Hecks::Utils.sanitize_constant(ref_found.name)
            # Find a display attribute (name, title, or first string attr)
            display_attr = ref_found.attributes.find { |da| da.name.to_s == "name" } ||
                           ref_found.attributes.find { |da| da.name.to_s == "title" } ||
                           ref_found.attributes.reject { |da| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(da.name.to_s) }.first
            display_method = display_attr ? display_attr.name.to_s : "id"
            hint = required_hint(agg, a.name)
            field_parts << "\"<label>#{ref_safe}#{hint}</label><select name='#{a.name}' required>\" + " \
              "#{ref_const}.all.map { |r| selected = r.id == req.query[\"id\"] ? \" selected\" : \"\"; " \
              "\"<option value='\" + r.id + \"'\" + selected + \">\" + r.#{display_method}.to_s + \"</option>\" }.join + \"</select>\""
          else
            hint = required_hint(agg, a.name)
            label = a.name.to_s.split("_").map(&:capitalize).join(" ")
            field_parts << "\"<label>#{label}#{hint}</label><input name='#{a.name}' type='text' required>\""
          end
        else
          type = case a.type.to_s
                 when /Integer/ then "number"
                 when /Float/ then "number"
                 else "text"
                 end
          step = a.type.to_s =~ /Float/ ? " step='any'" : ""
          hint = required_hint(agg, a.name)
          label = a.name.to_s.split("_").map(&:capitalize).join(" ")
          field_parts << "\"<label>#{label}#{hint}</label><input name='#{a.name}' type='#{type}'#{step} required>\""
        end
      end

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

      # POST handler
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

      # Re-render form with error under the right field
      rerender_parts = []
      cmd.attributes.each do |a|
        agg_s = Hecks::Utils.underscore(agg.name)
        label = a.name.to_s.split("_").map(&:capitalize).join(" ")
        val_expr = "params[\"#{a.name}\"]"

        if a.name.to_s == "#{agg_s}_id"
          rerender_parts << "\"<input type='hidden' name='#{a.name}' value='\" + h(#{val_expr} || \"\") + \"'>\""
        elsif a.name.to_s.end_with?("_id")
          ref_name = a.name.to_s.sub(/_id$/, "")
          ref_agg = @domain.aggregates.find { |ra| Hecks::Utils.underscore(ra.name) == ref_name }
          if ref_agg
            ref_const = Hecks::Utils.sanitize_constant(ref_agg.name)
            display = ref_agg.attributes.find { |da| da.name.to_s == "name" } ? "name" : "id"
            rerender_parts << "\"<label>#{label}</label><select name='#{a.name}' required>\" + #{ref_const}.all.map { |r| sel = r.id == #{val_expr} ? \" selected\" : \"\"; \"<option value='\" + r.id + \"'\" + sel + \">\" + r.#{display}.to_s + \"</option>\" }.join + \"</select>\" + (error_field == \"#{a.name}\" ? \"<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>\" + h(e.message) + \"</div>\" : \"\")"
          else
            rerender_parts << "\"<label>#{label}</label><input name='#{a.name}' type='text' value='\" + h(#{val_expr} || \"\") + \"' required>\" + (error_field == \"#{a.name}\" ? \"<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>\" + h(e.message) + \"</div>\" : \"\")"
          end
        else
          type = case a.type.to_s
                 when /Integer/ then "number"
                 when /Float/ then "number"
                 else "text"
                 end
          rerender_parts << "\"<label>#{label}</label><input name='#{a.name}' type='#{type}' value='\" + h(#{val_expr} || \"\") + \"' required>\" + (error_field == \"#{a.name}\" ? \"<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>\" + h(e.message) + \"</div>\" : \"\")"
        end
      end
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
    end
    lines
  end

  def config_route(mod)
    agg_rows = @domain.aggregates.map do |agg|
      safe = Hecks::Utils.sanitize_constant(agg.name)
      cmds = agg.commands.map(&:name).join(", ")
      ports = agg.ports.values.map { |p| "#{p.name}: #{p.allowed_methods.join(", ")}" }.join(" | ")
      ports = "(none)" if ports.empty?
      "\"<tr><td><a href='/#{plural(agg)}'>#{safe}</a></td>\" + " \
      "\"<td>\" + #{safe}.count.to_s + \"</td>\" + " \
      "\"<td class='mono'>#{cmds}</td>\" + " \
      "\"<td class='mono'>#{ports}</td></tr>\""
    end

    policies = (@domain.aggregates.flat_map { |a| a.policies.reject(&:guard?).map { |p| "#{p.event_name} &rarr; #{p.name}" } } +
                @domain.policies.map { |p| "#{p.event_name} &rarr; #{p.trigger_command}" })
    policy_html = policies.empty? ? "(none)" : "<ul>" + policies.map { |p| "<li class='mono'>#{p}</li>" }.join + "</ul>"

    [
      "        server.mount_proc \"/config\" do |req, res|",
      "          next unless req.request_method == \"GET\"",
      "          cfg = #{mod}.config || {}",
      "          rows = #{agg_rows.join(' + ')}",
      "          adapters = %w[memory sqlite].map { |a|",
      "            selected = cfg[:adapter].to_s == a ? \" selected\" : \"\"",
      "            \"<option value='\" + a + \"'\" + selected + \">\" + a + \"</option>\"",
      "          }.join",
      "          roles = #{mod}::ROLES.map { |r|",
      "            selected = #{mod}.current_role.to_s == r ? \" selected\" : \"\"",
      "            \"<option value='\" + r + \"'\" + selected + \">\" + r + \"</option>\"",
      "          }.join",
      "          html_response(res, layout(title: \"Config — #{mod}\", nav_items: nav) {",
      "            \"<h1>Configuration</h1>\" \\",
      "            \"<div class='detail'><dl>\" \\",
      "            \"<dt>Role</dt><dd><form method='post' action='/config/role' style='display:inline;background:none;padding:0;box-shadow:none'>\" \\",
      "            \"<select name='role' style='width:auto;display:inline;margin:0'>\" + roles + \"</select> \" \\",
      "            \"<button class='btn btn-sm' type='submit'>Switch</button></form></dd>\" \\",
      "            \"<dt>Adapter</dt><dd><form method='post' action='/config/reboot' style='display:inline;background:none;padding:0;box-shadow:none'>\" \\",
      "            \"<select name='adapter' style='width:auto;display:inline;margin:0'>\" + adapters + \"</select> \" \\",
      "            \"<button class='btn btn-sm' type='submit'>Switch</button></form></dd>\" \\",
      "            \"<dt>Events</dt><dd>\" + #{mod}.events.size.to_s + \" total</dd>\" \\",
      "            \"<dt>Booted</dt><dd>\" + (cfg[:booted_at] || \"unknown\").to_s + \"</dd>\" \\",
      "            \"<dt>Policies</dt><dd>#{policy_html}</dd>\" \\",
      "            \"</dl></div>\" \\",
      "            \"<h2 style='margin-top:2rem'>Aggregates</h2>\" \\",
      "            \"<table><thead><tr><th>Aggregate</th><th>Count</th><th>Commands</th><th>Ports</th></tr></thead><tbody>\" + rows + \"</tbody></table>\"",
      "          })",
      "        end",
      ""
    ]
  end

  def reboot_route(mod)
    [
      "        server.mount_proc \"/config/reboot\" do |req, res|",
      "          adapter = (req.query[\"adapter\"] || \"memory\").to_sym",
      "          #{mod}.reboot(adapter: adapter)",
      "          res.set_redirect(WEBrick::HTTPStatus::SeeOther, \"/config\")",
      "        end",
      "",
      "        server.mount_proc \"/config/role\" do |req, res|",
      "          #{mod}.current_role = req.query[\"role\"] || #{mod}.current_role",
      "          res.set_redirect(WEBrick::HTTPStatus::SeeOther, \"/config\")",
      "        end",
      ""
    ]
  end
end
end
