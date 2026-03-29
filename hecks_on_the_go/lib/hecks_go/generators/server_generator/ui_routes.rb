# HecksOnTheGo::ServerGenerator::UIRoutes
#
# Generates Go route handlers for form pages and the config page.
# All display conventions come from contracts.
#
module HecksOnTheGo
  class ServerGenerator < Hecks::Generator
    module UIRoutes
      private

      def form_routes
        ac = HecksTemplating::AggregateContract
        lines = []
        lines << "\t// Form routes (types in renderer.go)"

        @domain.aggregates.each do |agg|
          safe = agg.name
          plural = GoUtils.snake_case(safe) + "s"
          agg_snake = GoUtils.snake_case(safe)

          agg.commands.each do |cmd|
            cmd_snake = GoUtils.snake_case(cmd.name)
            self_id = ac.self_ref_attr(cmd, agg_snake)

            lines << "\tmux.HandleFunc(\"GET /#{plural}/#{cmd_snake}/new\", func(w http.ResponseWriter, r *http.Request) {"
            lines << "\t\tfields := []FormField{"
            cmd.attributes.each do |a|
              if a == self_id
                lines << "\t\t\t{Type: \"hidden\", Name: \"#{a.name}\", Value: r.URL.Query().Get(\"id\")},"
              elsif a.name.to_s.end_with?("_id")
                # Find referenced aggregate: explicit reference_to or name convention
                ref_agg = if a.reference?
                  @domain.aggregates.find { |ra| ra.name == a.type.to_s }
                else
                  ref_name = a.name.to_s.sub(/_id$/, "")
                  @domain.aggregates.find { |ra| GoUtils.snake_case(ra.name) == ref_name }
                end
                if ref_agg
                  lines << "\t\t\t// #{ref_agg.name} dropdown built dynamically below"
                else
                  label = HecksTemplating::UILabelContract.label(a.name)
                  lines << "\t\t\t{Type: \"input\", Name: \"#{a.name}\", Label: \"#{label}\", InputType: \"text\", Required: true},"
                end
              else
                agg_attr = agg.attributes.find { |aa| aa.name == a.name }
                enum_values = agg_attr&.enum
                label = HecksTemplating::UILabelContract.label(a.name)
                if enum_values && !enum_values.empty?
                  opts = enum_values.map { |v| "FormOption{Value: \"#{v}\", Label: \"#{v}\"}" }.join(", ")
                  lines << "\t\t\t{Type: \"select\", Name: \"#{a.name}\", Label: \"#{label}\", Required: true, Options: []FormOption{#{opts}}},"
                else
                  go_type = GoUtils.go_type(a)
                  input_type = HecksTemplating::FormParsingContract.input_type(go_type)
                  step = HecksTemplating::FormParsingContract.step?(go_type) ? ", Step: true" : ""
                  lines << "\t\t\t{Type: \"input\", Name: \"#{a.name}\", Label: \"#{label}\", InputType: \"#{input_type}\", Required: true#{step}},"
                end
              end
            end
            lines << "\t\t}"

            # Build dropdowns for ref fields
            cmd.attributes.each do |a|
              next if a == self_id
              next unless a.name.to_s.end_with?("_id")
              ref_agg = if a.reference?
                @domain.aggregates.find { |ra| ra.name == a.type.to_s }
              else
                ref_name = a.name.to_s.sub(/_id$/, "")
                @domain.aggregates.find { |ra| GoUtils.snake_case(ra.name) == ref_name }
              end
              next unless ref_agg
              ref_safe = ref_agg.name
              display = HecksTemplating::DisplayContract.go_reference_display_field(ref_agg)
              label = HecksTemplating::UILabelContract.label(a.name.to_s.sub(/_id$/, ""))
              lines << "\t\t#{ref_safe.downcase}s, _ := app.#{ref_safe}Repo.All()"
              lines << "\t\tvar #{ref_safe.downcase}Opts []FormOption"
              lines << "\t\tfor _, item := range #{ref_safe.downcase}s {"
              lines << "\t\t\t#{ref_safe.downcase}Opts = append(#{ref_safe.downcase}Opts, FormOption{Value: item.ID, Label: fmt.Sprintf(\"%v\", item.#{display}), Selected: item.ID == r.URL.Query().Get(\"id\")})"
              lines << "\t\t}"
              lines << "\t\tfields = append(fields, FormField{Type: \"select\", Name: \"#{a.name}\", Label: \"#{label}\", Required: true, Options: #{ref_safe.downcase}Opts})"
            end

            lines << "\t\trenderer.Render(w, \"form\", \"#{cmd.name}\", FormData{"
            lines << "\t\t\tCommandName: \"#{HecksTemplating::UILabelContract.label(cmd.name)}\","
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
        dc = HecksTemplating::DisplayContract
        all_roles = dc.available_roles(@domain)
        policies = dc.policy_labels(@domain)

        vc = HecksTemplating::ViewContract
        lines = []
        lines << "\t// Config"
        lines << "\t#{vc.go_struct(:config_agg, vc::CONFIG[:structs][:config_agg])}"
        lines << "\t#{vc.go_struct(:config_data, vc::CONFIG[:fields])}"
        lines << "\tcurrentRole := \"#{all_roles.first}\""
        lines << "\tmux.HandleFunc(\"GET /config\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\taggs := []ConfigAgg{"
        @domain.aggregates.each do |agg|
          plural = GoUtils.snake_case(agg.name) + "s"
          summary = dc.aggregate_summary(agg)
          lines << "\t\t\t{Name: \"#{agg.name}\", Href: \"/#{plural}\", Commands: \"#{summary[:commands]}\", Ports: \"#{summary[:ports]}\"},"
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
