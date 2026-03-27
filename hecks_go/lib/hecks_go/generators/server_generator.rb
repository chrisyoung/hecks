require_relative "server_generator/ui_routes"

# HecksGo::ServerGenerator
#
# Generates a Go HTTP server using net/http with JSON API routes and
# HTML UI routes rendered via html/template.
#
module HecksGo
  class ServerGenerator
    include GoUtils
    include UIRoutes

    def initialize(domain, module_path:)
      @domain = domain
      @module_path = module_path
    end

    def generate
      lines = []
      lines << "package server"
      lines << ""
      lines << "import ("
      lines << "\t\"encoding/json\""
      lines << "\t\"fmt\""
      lines << "\t\"net/http\""
      # Add time import if any aggregate has Date/DateTime attributes used in commands
      has_dates = @domain.aggregates.any? { |a| a.commands.any? { |c| c.attributes.any? { |attr| attr.type.to_s =~ /Date/ } } }
      lines << "\t\"time\"" if has_dates
      lines << "\t\"os\""
      lines << "\t\"path/filepath\""
      lines << "\t\"#{@module_path}/domain\""
      lines << "\t\"#{@module_path}/adapters/memory\""
      lines << "\t\"#{@module_path}/runtime\""
      lines << ")"
      lines << ""
      lines.concat(app_struct)
      lines.concat(start_method)
      lines.concat(helper_methods)
      lines.join("\n") + "\n"
    end

    private

    def app_struct
      lines = []
      lines << "type App struct {"
      @domain.aggregates.each { |agg| lines << "\t#{agg.name}Repo domain.#{agg.name}Repository" }
      lines << "\tEventBus *runtime.EventBus"
      lines << "\tCommandBus *runtime.CommandBus"
      lines << "}"
      lines << ""
      lines << "func NewApp() *App {"
      lines << "\teventBus := runtime.NewEventBus()"
      lines << "\treturn &App{"
      @domain.aggregates.each { |agg| lines << "\t\t#{agg.name}Repo: memory.New#{agg.name}MemoryRepository()," }
      lines << "\t\tEventBus: eventBus,"
      lines << "\t\tCommandBus: runtime.NewCommandBus(eventBus),"
      lines << "\t}"
      lines << "}"
      lines << ""
      lines
    end

    def start_method
      lines = []
      lines << "func (app *App) Start(port int) error {"
      lines << "\tmux := http.NewServeMux()"
      lines << ""
      lines << "\texe, _ := os.Executable()"
      lines << "\tviewsDir := filepath.Join(filepath.Dir(exe), \"..\", \"views\")"
      lines << "\tif _, err := os.Stat(viewsDir); err != nil { viewsDir = \"views\" }"
      lines << "\tnav := []NavItem{"
      lines << "\t\t{Label: \"Home\", Href: \"/\"},"
      @domain.aggregates.each do |agg|
        group = agg.origin_domain || ""
        lines << "\t\t{Label: \"#{agg.name}s\", Href: \"/#{GoUtils.snake_case(agg.name)}s\", Group: \"#{group}\"},"
      end
      lines << "\t\t{Label: \"Config\", Href: \"/config\", Group: \"System\"},"
      lines << "\t}"
      lines << "\trenderer := NewRenderer(viewsDir, \"#{@domain.name}Domain\", nav)"
      lines << ""
      lines.concat(home_route)
      lines.concat(json_routes)
      lines.concat(html_routes)
      lines.concat(form_routes)
      lines.concat(config_route)
      lines << "\taddr := fmt.Sprintf(\":%d\", port)"
      lines << "\tfmt.Printf(\"#{@domain.name}Domain on http://localhost%s\\n\", addr)"
      lines << "\treturn http.ListenAndServe(addr, mux)"
      lines << "}"
      lines << ""
      lines
    end

    def home_route
      agg_data = @domain.aggregates.map do |agg|
        plural = GoUtils.snake_case(agg.name) + "s"
        attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
        "{Name: \"#{agg.name}s\", Href: \"/#{plural}\", Commands: #{agg.commands.size}, Attributes: #{attrs.size}, Policies: #{agg.policies.size}}"
      end
      lines = []
      lines << "\ttype HomeAgg struct { Name string; Href string; Commands int; Attributes int; Policies int }"
      lines << "\ttype HomeData struct { DomainName string; Aggregates []HomeAgg }"
      lines << "\tmux.HandleFunc(\"GET /{$}\", func(w http.ResponseWriter, r *http.Request) {"
      lines << "\t\trenderer.Render(w, \"home\", \"#{@domain.name}Domain\", HomeData{"
      lines << "\t\t\tDomainName: \"#{@domain.name}Domain\", Aggregates: []HomeAgg{#{agg_data.join(', ')}},"
      lines << "\t\t})"
      lines << "\t})"
      lines << ""
      lines
    end

    def json_routes
      lines = []
      @domain.aggregates.each do |agg|
        safe = agg.name
        plural = GoUtils.snake_case(safe) + "s"
        attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
        agg_snake = GoUtils.snake_case(safe)

        # GET — index (HTML or JSON)
        cols = attrs.map { |a| "{Label: \"#{a.name.to_s.split("_").map(&:capitalize).join(" ")}\"}" }
        create_cmds = agg.commands.reject { |c| c.attributes.any? { |a| a.name.to_s == "#{agg_snake}_id" } }
        btns = create_cmds.map { |c| "{Label: \"#{c.name}\", Href: \"/#{plural}/#{GoUtils.snake_case(c.name)}/new\", Allowed: true}" }
        cell_exprs = attrs.map { |a| a.list? ? "fmt.Sprintf(\"%d items\", len(obj.#{GoUtils.pascal_case(a.name)}))" : "fmt.Sprintf(\"%v\", obj.#{GoUtils.pascal_case(a.name)})" }

        lines << "\ttype #{safe}Col struct { Label string }"
        lines << "\ttype #{safe}Item struct { ID string; ShortID string; ShowHref string; Cells []string }"
        lines << "\ttype #{safe}Btn struct { Label string; Href string; Allowed bool }"
        lines << "\ttype #{safe}IndexData struct { AggregateName string; Items []#{safe}Item; Columns []#{safe}Col; Buttons []#{safe}Btn }"
        lines << "\tmux.HandleFunc(\"GET /#{plural}\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tif r.Header.Get(\"Accept\") == \"application/json\" || r.URL.Query().Get(\"format\") == \"json\" {"
        lines << "\t\t\titems, _ := app.#{safe}Repo.All(); jsonResponse(w, items); return"
        lines << "\t\t}"
        lines << "\t\titems, _ := app.#{safe}Repo.All()"
        lines << "\t\tvar rows []#{safe}Item"
        lines << "\t\tfor _, obj := range items {"
        lines << "\t\t\tsid := obj.ID; if len(sid)>8 { sid=sid[:8]+\"...\" }"
        lines << "\t\t\trows = append(rows, #{safe}Item{ID: obj.ID, ShortID: sid, ShowHref: \"/#{plural}/show?id=\"+obj.ID, Cells: []string{#{cell_exprs.join(', ')}}})"
        lines << "\t\t}"
        lines << "\t\trenderer.Render(w, \"index\", \"#{safe}s\", #{safe}IndexData{AggregateName: \"#{safe}\", Items: rows, Columns: []#{safe}Col{#{cols.join(', ')}}, Buttons: []#{safe}Btn{#{btns.join(', ')}}})"
        lines << "\t})"
        lines << ""

        # GET find
        lines << "\tmux.HandleFunc(\"GET /#{plural}/find\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\titem, _ := app.#{safe}Repo.Find(r.URL.Query().Get(\"id\"))"
        lines << "\t\tif item == nil { http.Error(w, `{\"error\":\"not found\"}`, 404); return }"
        lines << "\t\tjsonResponse(w, item)"
        lines << "\t})"
        lines << ""

        # POST per command
        agg.commands.each do |cmd|
          cmd_snake = GoUtils.snake_case(cmd.name)
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
        end
      end
      lines
    end

    def html_routes
      lines = []
      @domain.aggregates.each do |agg|
        safe = agg.name
        plural = GoUtils.snake_case(safe) + "s"
        attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }

        lines << "\ttype #{safe}Field struct { Label string; Value string }"
        lines << "\ttype #{safe}ShowItem struct { ID string; Fields []#{safe}Field }"
        lines << "\ttype #{safe}ShowData struct { AggregateName string; BackHref string; Item #{safe}ShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }"
        lines << "\tmux.HandleFunc(\"GET /#{plural}/show\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tobj, _ := app.#{safe}Repo.Find(r.URL.Query().Get(\"id\"))"
        lines << "\t\tif obj == nil { http.Error(w, \"Not found\", 404); return }"
        lines << "\t\tfields := []#{safe}Field{"
        attrs.each do |a|
          field = GoUtils.pascal_case(a.name)
          label = a.name.to_s.split("_").map(&:capitalize).join(" ")
          lines << "\t\t\t{Label: \"#{label}\", Value: fmt.Sprintf(\"%v\", obj.#{field})},"
        end
        lines << "\t\t}"
        lines << "\t\trenderer.Render(w, \"show\", \"#{safe}\", #{safe}ShowData{AggregateName: \"#{safe}\", BackHref: \"/#{plural}\", Item: #{safe}ShowItem{ID: obj.ID, Fields: fields}})"
        lines << "\t})"
        lines << ""
      end
      lines
    end

    def helper_methods
      [
        "func jsonResponse(w http.ResponseWriter, data interface{}) {",
        "\tw.Header().Set(\"Content-Type\", \"application/json\")",
        "\tjson.NewEncoder(w).Encode(data)",
        "}",
        "",
        "func jsonError(w http.ResponseWriter, err error) {",
        "\tw.Header().Set(\"Content-Type\", \"application/json\")",
        "\tw.WriteHeader(422)",
        "\tjson.NewEncoder(w).Encode(map[string]string{\"error\": err.Error()})",
        "}",
      ]
    end
  end
end
