# HecksStatic::UIGenerator::ConfigRoutes
#
# Generates the /config page route that prepares data and renders
# the config.erb template. Also generates /config/reboot and /config/role.
#
module HecksStatic
  class UIGenerator
    module ConfigRoutes
      private

      def config_route(mod)
        agg_rows = @domain.aggregates.map do |agg|
          safe = Hecks::Utils.sanitize_constant(agg.name)
          cmds = agg.commands.map(&:name).join(", ")
          ports = agg.ports.values.map { |p| "#{p.name}: #{p.allowed_methods.join(", ")}" }.join(" | ")
          ports = "(none)" if ports.empty?
          "{ name: \"#{safe}\", href: \"/#{plural(agg)}\", count: #{safe}.count, commands: \"#{cmds}\", ports: \"#{ports}\" }"
        end

        policies = (@domain.aggregates.flat_map { |a| a.policies.reject(&:guard?).map { |p| "#{p.event_name} → #{p.name}" } } +
                    @domain.policies.map { |p| "#{p.event_name} → #{p.trigger_command}" })

        [
          "        server.mount_proc \"/config\" do |req, res|",
          "          next unless req.request_method == \"GET\"",
          "          cfg = #{mod}.config || {}",
          "          html = renderer.render(:config, title: \"Config — #{mod}\", brand: brand, nav_items: nav,",
          "            roles: #{mod}::ROLES, current_role: #{mod}.current_role.to_s,",
          "            adapters: %w[memory filesystem sqlite], current_adapter: cfg[:adapter].to_s,",
          "            event_count: #{mod}.events.size, booted_at: (cfg[:booted_at] || \"unknown\").to_s,",
          "            policies: #{policies.inspect},",
          "            aggregates: [#{agg_rows.join(', ')}])",
          "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
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
end
