require_relative "ui_generator/form_routes"
require_relative "ui_generator/config_routes"

module HecksStatic
# HecksStatic::UIGenerator
#
# Generates route handlers that prepare data and render ERB templates.
# Each route builds a locals hash and calls renderer.render(:template, locals).
#
class UIGenerator
  include FormRoutes
  include ConfigRoutes

  def initialize(domain)
    @domain = domain
  end

  def generate(mod, gem_name)
    lines = []
    lines << "require \"erb\""
    lines << "require_relative \"renderer\""
    lines << ""
    lines << "module #{mod}"
    lines << "  module Server"
    lines << "    module UIRoutes"
    lines << ""
    lines << "      def mount_ui_routes(server)"
    lines << "        views = File.expand_path(\"views\", __dir__)"
    lines << "        renderer = Renderer.new(views)"
    lines << "        nav = #{nav_items.inspect}"
    lines << "        brand = \"#{mod}\""
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

  def humanize(name)
    name.to_s.split("_").map(&:capitalize).join(" ")
  end

  def root_route(mod)
    agg_data = @domain.aggregates.map do |agg|
      "{ name: \"#{agg.name}s\", href: \"/#{plural(agg)}\", commands: #{agg.commands.size}, attributes: #{user_attrs(agg).size} }"
    end
    [
      "        server.mount_proc \"/\" do |req, res|",
      "          next unless req.path == \"/\"",
      "          html = renderer.render(:home, title: \"#{mod}\", brand: brand, nav_items: nav,",
      "            domain_name: \"#{mod}\", aggregates: [#{agg_data.join(', ')}])",
      "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
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

    columns = attrs.map { |a| "{ label: \"#{humanize(a.name)}\" }" }
    btns = create_cmds.map { |c| cm = Hecks::Utils.underscore(c.name); "{ label: \"#{c.name}\", href: \"/#{p}/#{cm}/new\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }" }
    row_acts = update_cmds.map { |c| cm = Hecks::Utils.underscore(c.name); "{ label: \"#{c.name}\", href_prefix: \"/#{p}/#{cm}/new?id=\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }" }

    cell_exprs = attrs.map do |a|
      if a.list?
        "obj.#{a.name}.size.to_s + \" items\""
      else
        "obj.#{a.name}.to_s"
      end
    end
    cells_code = cell_exprs.map { |e| e }.join(", ")

    [
      "        server.mount_proc \"/#{p}\" do |req, res|",
      "          next unless req.path == \"/#{p}\"",
      "          all_items = #{safe}.all",
      "          items = all_items.map { |obj| { id: obj.id, short_id: obj.id[0..7] + \"...\", show_href: \"/#{p}/show?id=\" + obj.id, cells: [#{cells_code}] } }",
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
    safe = Hecks::Utils.sanitize_constant(agg.name)
    p = plural(agg)
    attrs = user_attrs(agg)
    agg_snake = Hecks::Utils.underscore(agg.name)

    field_exprs = attrs.map do |a|
      if a.list?
        vo = agg.value_objects.find { |v| v.name == a.type.to_s }
        if vo
          vo_attrs = vo.attributes.map(&:name).map(&:to_s)
          items_expr = "obj.#{a.name}.map { |v| #{vo_attrs.map { |va| "v.#{va}.to_s" }.join(' + " — " + ')} }"
          "{ label: \"#{humanize(a.name)}\", type: :list, items: #{items_expr} }"
        else
          "{ label: \"#{humanize(a.name)}\", type: :list, items: obj.#{a.name}.map(&:to_s) }"
        end
      else
        "{ label: \"#{humanize(a.name)}\", value: obj.#{a.name}.to_s }"
      end
    end

    # Collect buttons
    btn_parts = []
    update_cmds = agg.commands.select { |c| self_ref?(c, agg_snake) }
    update_cmds.each do |c|
      cm = Hecks::Utils.underscore(c.name)
      btn_parts << "{ label: \"#{c.name}\", href: \"/#{p}/#{cm}/new?id=\" + obj.id, allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }"
    end
    # Cross-aggregate commands
    snake = Hecks::Utils.underscore(agg.name)
    @domain.aggregates.each do |other|
      next if other.name == agg.name
      other_safe = Hecks::Utils.sanitize_constant(other.name)
      other_p = plural(other)
      other.commands.each do |cmd|
        next unless cmd.attributes.any? { |a| a.name.to_s == "#{snake}_id" }
        cm = Hecks::Utils.underscore(cmd.name)
        btn_parts << "{ label: \"#{cmd.name}\", href: \"/#{other_p}/#{cm}/new?id=\" + obj.id, allowed: #{mod}.role_allows?(\"#{other_safe}\", \"#{cm}\") }"
      end
    end

    [
      "        server.mount_proc \"/#{p}/show\" do |req, res|",
      "          obj = #{safe}.find(req.query[\"id\"])",
      "          unless obj",
      "            res.status = 404; res.body = \"Not found\"; next",
      "          end",
      "          html = renderer.render(:show, title: \"#{safe} — #{mod}\", brand: brand, nav_items: nav,",
      "            aggregate_name: \"#{safe}\", back_href: \"/#{p}\",",
      "            item: { id: obj.id, fields: [#{field_exprs.join(', ')}] },",
      "            buttons: [#{btn_parts.join(', ')}])",
      "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
      "        end",
      ""
    ]
  end
end
end
