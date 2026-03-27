# HecksGo::ServerGenerator::UIRoutes
#
# Generates Go route handlers for form pages and the config page.
# Extracted from ServerGenerator to keep it under 200 lines.
#
module HecksGo
  class ServerGenerator
    module UIRoutes
      private

      def form_routes
        lines = []
        lines << "\t// Form routes (types in renderer.go)"

        @domain.aggregates.each do |agg|
          safe = agg.name
          plural = GoUtils.snake_case(safe) + "s"
          agg_snake = GoUtils.snake_case(safe)

          agg.commands.each do |cmd|
            cmd_snake = GoUtils.snake_case(cmd.name)
            self_id = cmd.attributes.find { |a| a.name.to_s == "#{agg_snake}_id" }

            lines << "\tmux.HandleFunc(\"GET /#{plural}/#{cmd_snake}/new\", func(w http.ResponseWriter, r *http.Request) {"
            lines << "\t\tfields := []FormField{"
            cmd.attributes.each do |a|
              if a == self_id
                lines << "\t\t\t{Type: \"hidden\", Name: \"#{a.name}\", Value: r.URL.Query().Get(\"id\")},"
              elsif a.name.to_s.end_with?("_id")
                ref_name = a.name.to_s.sub(/_id$/, "")
                ref_agg = @domain.aggregates.find { |ra| GoUtils.snake_case(ra.name) == ref_name }
                if ref_agg
                  lines << "\t\t\t// #{ref_agg.name} dropdown built dynamically below"
                end
              else
                is_float = a.type.to_s =~ /Float/
                input_type = case a.type.to_s
                             when /Integer/ then "number"
                             when /Float/ then "number"
                             else "text"
                             end
                label = a.name.to_s.split("_").map(&:capitalize).join(" ")
                step = is_float ? ", Step: true" : ""
                lines << "\t\t\t{Type: \"input\", Name: \"#{a.name}\", Label: \"#{label}\", InputType: \"#{input_type}\", Required: true#{step}},"
              end
            end
            lines << "\t\t}"

            # Build dropdowns for ref fields
            cmd.attributes.each do |a|
              next if a == self_id
              next unless a.name.to_s.end_with?("_id")
              ref_name = a.name.to_s.sub(/_id$/, "")
              ref_agg = @domain.aggregates.find { |ra| GoUtils.snake_case(ra.name) == ref_name }
              next unless ref_agg
              ref_safe = ref_agg.name
              display = ref_agg.attributes.find { |da| da.name.to_s == "name" } ? GoUtils.pascal_case("name") : "ID"
              label = ref_name.split("_").map(&:capitalize).join(" ")
              lines << "\t\t#{ref_safe.downcase}s, _ := app.#{ref_safe}Repo.All()"
              lines << "\t\tvar #{ref_safe.downcase}Opts []FormOption"
              lines << "\t\tfor _, item := range #{ref_safe.downcase}s {"
              lines << "\t\t\t#{ref_safe.downcase}Opts = append(#{ref_safe.downcase}Opts, FormOption{Value: item.ID, Label: fmt.Sprintf(\"%v\", item.#{display}), Selected: item.ID == r.URL.Query().Get(\"id\")})"
              lines << "\t\t}"
              lines << "\t\tfields = append(fields, FormField{Type: \"select\", Name: \"#{a.name}\", Label: \"#{label}\", Required: true, Options: #{ref_safe.downcase}Opts})"
            end

            lines << "\t\trenderer.Render(w, \"form\", \"#{cmd.name}\", FormData{"
            lines << "\t\t\tCommandName: \"#{cmd.name}\","
            lines << "\t\t\tAction: \"/#{plural}/#{cmd_snake}\","
            lines << "\t\t\tFields: fields,"
            lines << "\t\t})"
            lines << "\t})"
            lines << ""
          end
        end
        lines
      end

      def config_route
        all_roles = @domain.aggregates.flat_map { |a| a.ports.keys }.uniq.map(&:to_s)
        all_roles = ["admin"] if all_roles.empty?
        policies = @domain.aggregates.flat_map { |a| a.policies.reject { |p| p.respond_to?(:guard?) && p.guard? }.map { |p| "#{p.event_name} → #{p.name}" } }
        policies += @domain.policies.map { |p| "#{p.event_name} → #{p.trigger_command}" }

        vc = Hecks::ViewContracts
        lines = []
        lines << "\t// Config"
        lines << "\t#{vc.go_struct(:config_agg, vc::CONFIG[:structs][:config_agg])}"
        lines << "\t#{vc.go_struct(:config_data, vc::CONFIG[:fields])}"
        lines << "\tcurrentRole := \"#{all_roles.first}\""
        lines << "\tmux.HandleFunc(\"GET /config\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\taggs := []ConfigAgg{"
        @domain.aggregates.each do |agg|
          plural = GoUtils.snake_case(agg.name) + "s"
          cmds = agg.commands.map(&:name).join(", ")
          ports = agg.ports.values.map { |p| "#{p.name}: #{p.allowed_methods.join(", ")}" }.join(" | ")
          ports = "(none)" if ports.empty?
          lines << "\t\t\t{Name: \"#{agg.name}\", Href: \"/#{plural}\", Commands: \"#{cmds}\", Ports: \"#{ports}\"},"
        end
        lines << "\t\t}"
        @domain.aggregates.each_with_index do |agg, idx|
          lines << "\t\t#{agg.name.downcase}Count, _ := app.#{agg.name}Repo.Count()"
          lines << "\t\taggs[#{idx}].Count = #{agg.name.downcase}Count"
        end
        lines << "\t\trenderer.Render(w, \"config\", \"Config\", ConfigData{"
        lines << "\t\t\tRoles: []string{#{all_roles.map { |r| "\"#{r}\"" }.join(', ')}},"
        lines << "\t\t\tCurrentRole: currentRole,"
        lines << "\t\t\tAdapters: []string{\"memory\", \"filesystem\"},"
        lines << "\t\t\tCurrentAdapter: \"memory\","
        lines << "\t\t\tEventCount: len(app.EventBus.Events()),"
        lines << "\t\t\tBootedAt: \"running\","
        lines << "\t\t\tPolicies: []string{#{policies.map { |p| "\"#{p}\"" }.join(', ')}},"
        lines << "\t\t\tAggregates: aggs,"
        lines << "\t\t})"
        lines << "\t})"
        lines << ""
        lines
      end
    end
  end
end
