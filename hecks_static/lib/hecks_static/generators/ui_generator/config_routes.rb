# HecksStatic::UIGenerator::ConfigRoutes
#
# Generates the /config page showing roles, adapter, events, policies,
# and aggregate info. Also generates /config/reboot and /config/role routes.
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
          "          adapters = %w[memory filesystem sqlite].map { |a|",
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
end
