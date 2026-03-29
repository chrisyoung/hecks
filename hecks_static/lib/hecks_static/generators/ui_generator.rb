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
      items << { label: Hecks::UILabelContract.plural_label(agg.name), href: "/#{plural(agg)}" }
    end
    items << { label: "Config", href: "/config" }
    items
  end

  def plural(agg)
    Hecks::Templating::Names.aggregate_slug(agg.name)
  end

  def user_attrs(agg)
    agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
  end

  def self_ref?(cmd, agg_snake)
    suffixes = agg_snake.split("_").each_index.map { |i|
      agg_snake.split("_").drop(i).join("_")
    }.uniq
    cmd.attributes.any? { |a|
      a.name.to_s.end_with?("_id") &&
        suffixes.any? { |s| a.name.to_s == "#{s}_id" }
    }
  end

  def find_self_ref_attr(cmd, agg)
    agg_snake = Hecks::Utils.underscore(agg.name)
    suffixes = agg_snake.split("_").each_index.map { |i|
      agg_snake.split("_").drop(i).join("_")
    }.uniq
    cmd.attributes.find { |a|
      a.name.to_s.end_with?("_id") &&
        suffixes.any? { |s| a.name.to_s == "#{s}_id" }
    }
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
      d = Hecks::DisplayContract.home_aggregate_data(agg, plural(agg))
      "{ name: \"#{d[:name]}\", href: \"#{d[:href]}\", commands: #{d[:commands]}, attributes: #{d[:attributes]}, policies: #{d[:policies]} }"
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
    ac = Hecks::AggregateContract
    dc = Hecks::DisplayContract
    create_cmds, update_cmds = ac.partition_commands(agg)

    columns = attrs.map { |a| "{ label: \"#{humanize(a.name)}\" }" }
    btns = create_cmds.map { |c| cm = Hecks::Utils.underscore(c.name); "{ label: \"#{Hecks::UILabelContract.label(c.name)}\", href: \"/#{p}/#{cm}/new\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }" }
    row_acts = update_cmds.map do |c|
      cm = Hecks::Utils.underscore(c.name)
      if ac.direct_action?(c, agg_snake)
        self_id = ac.self_ref_attr(c, agg_snake)
        "{ label: \"#{Hecks::UILabelContract.label(c.name)}\", href_prefix: \"/#{p}/#{cm}/submit\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\"), direct: true, id_field: \"#{self_id&.name}\" }"
      else
        "{ label: \"#{Hecks::UILabelContract.label(c.name)}\", href_prefix: \"/#{p}/#{cm}/new?id=\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }"
      end
    end

    cell_exprs = attrs.map { |a| dc.cell_expression(a, "obj", lang: :ruby) }
    cells_code = cell_exprs.map { |e| e }.join(", ")

    [
      "        server.mount_proc \"/#{p}\" do |req, res|",
      "          next unless req.path == \"/#{p}\"",
      "          all_items = #{safe}.all",
      "          items = all_items.map { |obj| { id: obj.id, short_id: #{Hecks::ViewContract.ruby_short_id('obj.id')}, show_href: \"/#{p}/show?id=\" + obj.id, cells: [#{cells_code}] } }",
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

    lc = agg.lifecycle
    lc_field = lc&.field&.to_s

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
      elsif lc_field && a.name.to_s == lc_field
        transitions = Hecks::DisplayContract.lifecycle_transitions(lc)
        "{ label: \"#{humanize(a.name)}\", type: :lifecycle, value: obj.#{a.name}.to_s, transitions: #{transitions.inspect} }"
      else
        "{ label: \"#{humanize(a.name)}\", value: obj.#{a.name}.to_s }"
      end
    end

    # Collect buttons — from contract
    ac = Hecks::AggregateContract
    btn_parts = []
    _, update_cmds = ac.partition_commands(agg)
    update_cmds.each do |c|
      cm = Hecks::Utils.underscore(c.name)
      if ac.direct_action?(c, agg_snake)
        self_id = ac.self_ref_attr(c, agg_snake)
        btn_parts << "{ label: \"#{Hecks::UILabelContract.label(c.name)}\", href: \"/#{p}/#{cm}/submit\", allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\"), direct: true, id_field: \"#{self_id.name}\" }"
      else
        btn_parts << "{ label: \"#{Hecks::UILabelContract.label(c.name)}\", href: \"/#{p}/#{cm}/new?id=\" + obj.id, allowed: #{mod}.role_allows?(\"#{safe}\", \"#{cm}\") }"
      end
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
        btn_parts << "{ label: \"#{Hecks::UILabelContract.label(cmd.name)}\", href: \"/#{other_p}/#{cm}/new?id=\" + obj.id, allowed: #{mod}.role_allows?(\"#{other_safe}\", \"#{cm}\") }"
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
      "            id: obj.id, fields: [#{field_exprs.join(', ')}],",
      "            buttons: [#{btn_parts.join(', ')}])",
      "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
      "        end",
      ""
    ]
  end
end
end
