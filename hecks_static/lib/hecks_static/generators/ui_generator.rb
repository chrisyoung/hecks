require_relative "ui_generator/form_routes"
require_relative "ui_generator/config_routes"

module HecksStatic
# HecksStatic::UIGenerator
#
# Generates HTML routes for each aggregate: index (table), show (detail),
# and new (form per create command). Produces a Ruby file that mounts
# WEBrick routes alongside the JSON API.
#
class UIGenerator
  include FormRoutes
  include ConfigRoutes

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

  def self_ref?(cmd, agg_snake)
    cmd.attributes.any? { |a| a.name.to_s == "#{agg_snake}_id" }
  end

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

    agg_snake = Hecks::Utils.underscore(agg.name)
    update_cmds = agg.commands.select { |c| self_ref?(c, agg_snake) }
    update_btns = update_cmds.map do |c|
      cm = Hecks::Utils.underscore(c.name)
      "(#{mod}.role_allows?(\"#{safe}\", \"#{cm}\") ? \"<a class='btn btn-sm' href='/#{p}/#{cm}/new?id=\" + obj.id + \"'>#{c.name}</a> \" : \"<a class='btn btn-sm' href='/#{p}/#{cm}/new?id=\" + obj.id + \"' style='opacity:0.4'>#{c.name}</a> \")"
    end

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
end
end
