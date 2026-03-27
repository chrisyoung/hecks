# HecksGo::ServerGenerator::DataRoutes
#
# Generates Go route handlers for JSON API endpoints (index, find, POST commands)
# and HTML show pages. Struct types derive from ViewContracts.
#
module HecksGo
  class ServerGenerator
    module DataRoutes
      private

      def json_routes
        lines = []
        @domain.aggregates.each do |agg|
          safe = agg.name
          plural = GoUtils.snake_case(safe) + "s"
          attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
          agg_snake = GoUtils.snake_case(safe)

          lines.concat(index_route(agg, safe, plural, attrs, agg_snake))
          lines.concat(find_route(safe, plural))
          agg.commands.each { |cmd| lines.concat(command_route(safe, plural, cmd)) }
        end
        lines
      end

      def index_route(agg, safe, plural, attrs, agg_snake)
        vc = Hecks::ViewContracts
        cols = attrs.map { |a| "{Label: \"#{a.name.to_s.split("_").map(&:capitalize).join(" ")}\"}" }
        create_cmds = agg.commands.reject { |c| c.attributes.any? { |a| a.name.to_s == "#{agg_snake}_id" } }
        btns = create_cmds.map { |c| "{Label: \"#{c.name}\", Href: \"/#{plural}/#{GoUtils.snake_case(c.name)}/new\", Allowed: true}" }
        cell_exprs = attrs.map { |a| a.list? ? "fmt.Sprintf(\"%d items\", len(obj.#{GoUtils.pascal_case(a.name)}))" : "fmt.Sprintf(\"%v\", obj.#{GoUtils.pascal_case(a.name)})" }
        desc = agg.description || ""

        lines = []
        lines << "\t#{vc.go_struct(:column, vc::INDEX[:structs][:column], prefix: safe)}"
        lines << "\t#{vc.go_struct(:index_item, vc::INDEX[:structs][:index_item], prefix: safe)}"
        lines << "\t#{vc.go_struct(:button, vc::INDEX[:structs][:button], prefix: safe)}"
        lines << "\t#{vc.go_struct(:index_data, vc::INDEX[:fields], prefix: safe)}"
        lines << "\tmux.HandleFunc(\"GET /#{plural}\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tif r.Header.Get(\"Accept\") == \"application/json\" || r.URL.Query().Get(\"format\") == \"json\" {"
        lines << "\t\t\titems, _ := app.#{safe}Repo.All(); jsonResponse(w, items); return"
        lines << "\t\t}"
        lines << "\t\titems, _ := app.#{safe}Repo.All()"
        lines << "\t\tvar rows []#{safe}IndexItem"
        lines << "\t\tfor _, obj := range items {"
        lines << "\t\t\tsid := obj.ID; if len(sid)>8 { sid=sid[:8]+\"...\" }"
        lines << "\t\t\trows = append(rows, #{safe}IndexItem{Id: obj.ID, ShortId: sid, ShowHref: \"/#{plural}/show?id=\"+obj.ID, Cells: []string{#{cell_exprs.join(', ')}}})"
        lines << "\t\t}"
        lines << "\t\trenderer.Render(w, \"index\", \"#{safe}s\", #{safe}IndexData{AggregateName: \"#{safe}\", Description: \"#{desc}\", Items: rows, Columns: []#{safe}Column{#{cols.join(', ')}}, Buttons: []#{safe}Button{#{btns.join(', ')}}})"
        lines << "\t})"
        lines << ""
        lines
      end

      def find_route(safe, plural)
        [
          "\tmux.HandleFunc(\"GET /#{plural}/find\", func(w http.ResponseWriter, r *http.Request) {",
          "\t\titem, _ := app.#{safe}Repo.Find(r.URL.Query().Get(\"id\"))",
          "\t\tif item == nil { http.Error(w, `{\"error\":\"not found\"}`, 404); return }",
          "\t\tjsonResponse(w, item)",
          "\t})",
          "",
        ]
      end

      def command_route(safe, plural, cmd)
        cmd_snake = GoUtils.snake_case(cmd.name)
        lines = []
        lines << "\tmux.HandleFunc(\"POST /#{plural}/#{cmd_snake}\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tvar cmd domain.#{cmd.name}"
        lines << "\t\tif r.Header.Get(\"Content-Type\") == \"application/json\" {"
        lines << "\t\t\tif err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{\"error\":\"invalid json\"}`, 400); return }"
        lines << "\t\t} else {"
        lines << "\t\t\tr.ParseForm()"
        cmd.attributes.each do |a|
          field = GoUtils.pascal_case(a.name)
          case a.type.to_s
          when /Integer/
            lines << "\t\t\tif v := r.FormValue(\"#{a.name}\"); v != \"\" { fmt.Sscanf(v, \"%d\", &cmd.#{field}) }"
          when /Float/
            lines << "\t\t\tif v := r.FormValue(\"#{a.name}\"); v != \"\" { fmt.Sscanf(v, \"%f\", &cmd.#{field}) }"
          when /Date|DateTime/
            lines << "\t\t\tif v := r.FormValue(\"#{a.name}\"); v != \"\" { cmd.#{field}, _ = time.Parse(\"2006-01-02\", v) }"
          else
            lines << "\t\t\tcmd.#{field} = r.FormValue(\"#{a.name}\")"
          end
        end
        lines << "\t\t}"
        lines << "\t\tagg, event, err := cmd.Execute(app.#{safe}Repo)"
        lines << "\t\tif event != nil { app.EventBus.Publish(event) }"
        lines << "\t\tif err != nil {"
        lines << "\t\t\tif r.Header.Get(\"Content-Type\")==\"application/json\" { jsonError(w, err); return }"
        lines << "\t\t\thttp.Error(w, err.Error(), 422); return"
        lines << "\t\t}"
        lines << "\t\tif r.Header.Get(\"Content-Type\")==\"application/json\" { w.WriteHeader(201); jsonResponse(w, agg) } else {"
        lines << "\t\t\thttp.Redirect(w, r, \"/#{plural}/show?id=\"+agg.ID, http.StatusSeeOther)"
        lines << "\t\t}"
        lines << "\t})"
        lines << ""
        lines
      end

      def html_routes
        vc = Hecks::ViewContracts
        lines = []
        @domain.aggregates.each do |agg|
          safe = agg.name
          plural = GoUtils.snake_case(safe) + "s"
          attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }

          lines << "\t#{vc.go_struct(:show_field, vc::SHOW[:structs][:show_field], prefix: safe)}"
          lines << "\t#{vc.go_struct(:show_data, vc::SHOW[:fields], prefix: safe)}"
          lines << "\tmux.HandleFunc(\"GET /#{plural}/show\", func(w http.ResponseWriter, r *http.Request) {"
          lines << "\t\tobj, _ := app.#{safe}Repo.Find(r.URL.Query().Get(\"id\"))"
          lines << "\t\tif obj == nil { http.Error(w, \"Not found\", 404); return }"
          lines << "\t\tfields := []#{safe}ShowField{"
          attrs.each do |a|
            field = GoUtils.pascal_case(a.name)
            label = a.name.to_s.split("_").map(&:capitalize).join(" ")
            if a.list?
              lines << "\t\t\t{Label: \"#{label}\", Type: \"list\", Items: func() []string { var s []string; for _, v := range obj.#{field} { s = append(s, fmt.Sprintf(\"%v\", v)) }; return s }()},"
            else
              lines << "\t\t\t{Label: \"#{label}\", Value: fmt.Sprintf(\"%v\", obj.#{field})},"
            end
          end
          lines << "\t\t}"
          lines << "\t\trenderer.Render(w, \"show\", \"#{safe}\", #{safe}ShowData{AggregateName: \"#{safe}\", BackHref: \"/#{plural}\", Id: obj.ID, Fields: fields})"
          lines << "\t})"
          lines << ""
        end
        lines
      end
    end
  end
end
