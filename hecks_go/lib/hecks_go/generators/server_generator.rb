# HecksGo::ServerGenerator
#
# Generates a Go HTTP server using net/http with JSON API routes and
# HTML UI routes rendered via html/template. Same layout as the Ruby
# web explorer.
#
module HecksGo
  class ServerGenerator
    include GoUtils

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
      lines << "\t\"os\""
      lines << "\t\"path/filepath\""
      lines << "\t\"#{@module_path}/domain\""
      lines << "\t\"#{@module_path}/adapters/memory\""
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
      @domain.aggregates.each do |agg|
        lines << "\t#{agg.name}Repo domain.#{agg.name}Repository"
      end
      lines << "}"
      lines << ""
      lines << "func NewApp() *App {"
      lines << "\treturn &App{"
      @domain.aggregates.each do |agg|
        lines << "\t\t#{agg.name}Repo: memory.New#{agg.name}MemoryRepository(),"
      end
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
      lines << "\t// Template renderer"
      lines << "\texe, _ := os.Executable()"
      lines << "\tviewsDir := filepath.Join(filepath.Dir(exe), \"..\", \"views\")"
      lines << "\tif _, err := os.Stat(viewsDir); err != nil {"
      lines << "\t\tviewsDir = \"views\" // fallback to current directory"
      lines << "\t}"
      lines << "\tnav := []NavItem{"
      lines << "\t\t{Label: \"Home\", Href: \"/\"},"
      @domain.aggregates.each do |agg|
        plural = GoUtils.snake_case(agg.name) + "s"
        lines << "\t\t{Label: \"#{agg.name}s\", Href: \"/#{plural}\"},"
      end
      lines << "\t\t{Label: \"Config\", Href: \"/config\"},"
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
        "{Name: \"#{agg.name}s\", Href: \"/#{plural}\", Commands: #{agg.commands.size}, Attributes: #{agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }.size}}"
      end

      lines = []
      lines << "\t// Home"
      lines << "\ttype HomeAgg struct { Name string; Href string; Commands int; Attributes int }"
      lines << "\ttype HomeData struct { DomainName string; Aggregates []HomeAgg }"
      lines << "\tmux.HandleFunc(\"GET /{$}\", func(w http.ResponseWriter, r *http.Request) {"
      lines << "\t\trenderer.Render(w, \"home\", \"#{@domain.name}Domain\", HomeData{"
      lines << "\t\t\tDomainName: \"#{@domain.name}Domain\","
      lines << "\t\t\tAggregates: []HomeAgg{#{agg_data.join(', ')}},"
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

        # GET /pizzas — JSON list
        lines << "\tmux.HandleFunc(\"GET /#{plural}\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tif r.Header.Get(\"Accept\") == \"application/json\" || r.URL.Query().Get(\"format\") == \"json\" {"
        lines << "\t\t\titems, _ := app.#{safe}Repo.All()"
        lines << "\t\t\tjsonResponse(w, items)"
        lines << "\t\t\treturn"
        lines << "\t\t}"
        lines << "\t\t// HTML index"
        lines << "\t\ttype Col struct { Label string }"
        lines << "\t\ttype Item struct { ID string; ShortID string; ShowHref string; Cells []string }"
        lines << "\t\ttype Btn struct { Label string; Href string; Allowed bool }"
        lines << "\t\ttype IndexData struct { AggregateName string; Items []Item; Columns []Col; Buttons []Btn }"

        attrs = agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
        cols = attrs.map { |a| "{Label: \"#{a.name.to_s.split("_").map(&:capitalize).join(" ")}\"}" }
        lines << "\t\titems, _ := app.#{safe}Repo.All()"
        lines << "\t\tvar rows []Item"
        lines << "\t\tfor _, obj := range items {"
        lines << "\t\t\tshortID := obj.ID"
        lines << "\t\t\tif len(shortID) > 8 { shortID = shortID[:8] + \"...\" }"
        cell_exprs = attrs.map do |a|
          field = GoUtils.pascal_case(a.name)
          if a.list?
            "fmt.Sprintf(\"%d items\", len(obj.#{field}))"
          else
            "fmt.Sprintf(\"%v\", obj.#{field})"
          end
        end
        lines << "\t\t\trows = append(rows, Item{ID: obj.ID, ShortID: shortID, ShowHref: \"/#{plural}/show?id=\" + obj.ID, Cells: []string{#{cell_exprs.join(', ')}}})"
        lines << "\t\t}"

        # Buttons for create commands
        agg_snake = GoUtils.snake_case(safe)
        create_cmds = agg.commands.reject { |c| c.attributes.any? { |a| a.name.to_s == "#{agg_snake}_id" } }
        btns = create_cmds.map { |c| "{Label: \"#{c.name}\", Href: \"/#{plural}/#{GoUtils.snake_case(c.name)}/new\", Allowed: true}" }

        lines << "\t\trenderer.Render(w, \"index\", \"#{safe}s\", IndexData{"
        lines << "\t\t\tAggregateName: \"#{safe}\","
        lines << "\t\t\tItems: rows,"
        lines << "\t\t\tColumns: []Col{#{cols.join(', ')}},"
        lines << "\t\t\tButtons: []Btn{#{btns.join(', ')}},"
        lines << "\t\t})"
        lines << "\t})"
        lines << ""

        # GET /pizzas/find?id=
        lines << "\tmux.HandleFunc(\"GET /#{plural}/find\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tid := r.URL.Query().Get(\"id\")"
        lines << "\t\titem, _ := app.#{safe}Repo.Find(id)"
        lines << "\t\tif item == nil { http.Error(w, `{\"error\":\"not found\"}`, 404); return }"
        lines << "\t\tjsonResponse(w, item)"
        lines << "\t})"
        lines << ""

        # POST per command — JSON or form data
        agg.commands.each do |cmd|
          cmd_snake = GoUtils.snake_case(cmd.name)
          lines << "\tmux.HandleFunc(\"POST /#{plural}/#{cmd_snake}\", func(w http.ResponseWriter, r *http.Request) {"
          lines << "\t\tvar cmd domain.#{cmd.name}"
          lines << "\t\tif r.Header.Get(\"Content-Type\") == \"application/json\" {"
          lines << "\t\t\tif err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {"
          lines << "\t\t\t\thttp.Error(w, `{\"error\":\"invalid json\"}`, 400); return"
          lines << "\t\t\t}"
          lines << "\t\t} else {"
          lines << "\t\t\tr.ParseForm()"
          # Set each command field from form values
          cmd.attributes.each do |a|
            field = GoUtils.pascal_case(a.name)
            case a.type.to_s
            when /Integer/
              lines << "\t\t\tif v := r.FormValue(\"#{a.name}\"); v != \"\" { n, _ := fmt.Sscanf(v, \"%d\", &cmd.#{field}) ; _ = n }"
            when /Float/
              lines << "\t\t\tif v := r.FormValue(\"#{a.name}\"); v != \"\" { n, _ := fmt.Sscanf(v, \"%f\", &cmd.#{field}) ; _ = n }"
            else
              lines << "\t\t\tcmd.#{field} = r.FormValue(\"#{a.name}\")"
            end
          end
          lines << "\t\t}"
          lines << "\t\tagg, _, err := cmd.Execute(app.#{safe}Repo)"
          lines << "\t\tif err != nil {"
          lines << "\t\t\tif r.Header.Get(\"Content-Type\") == \"application/json\" {"
          lines << "\t\t\t\tjsonError(w, err); return"
          lines << "\t\t\t}"
          lines << "\t\t\thttp.Error(w, err.Error(), 422); return"
          lines << "\t\t}"
          lines << "\t\tif r.Header.Get(\"Content-Type\") == \"application/json\" {"
          lines << "\t\t\tw.WriteHeader(201); jsonResponse(w, agg)"
          lines << "\t\t} else {"
          lines << "\t\t\thttp.Redirect(w, r, \"/#{plural}/show?id=\" + agg.ID, http.StatusSeeOther)"
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

        # GET /pizzas/show?id=
        lines << "\ttype #{safe}Field struct { Label string; Value string }"
        lines << "\ttype #{safe}ShowItem struct { ID string; Fields []#{safe}Field }"
        lines << "\ttype #{safe}ShowData struct { AggregateName string; BackHref string; Item #{safe}ShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }"
        lines << "\tmux.HandleFunc(\"GET /#{plural}/show\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tid := r.URL.Query().Get(\"id\")"
        lines << "\t\tobj, _ := app.#{safe}Repo.Find(id)"
        lines << "\t\tif obj == nil { http.Error(w, \"Not found\", 404); return }"
        lines << "\t\tfields := []#{safe}Field{"
        attrs.each do |a|
          field = GoUtils.pascal_case(a.name)
          label = a.name.to_s.split("_").map(&:capitalize).join(" ")
          if a.list?
            lines << "\t\t\t{Label: \"#{label}\", Value: fmt.Sprintf(\"%d items\", len(obj.#{field}))},"
          else
            lines << "\t\t\t{Label: \"#{label}\", Value: fmt.Sprintf(\"%v\", obj.#{field})},"
          end
        end
        lines << "\t\t}"
        lines << "\t\trenderer.Render(w, \"show\", \"#{safe}\", #{safe}ShowData{"
        lines << "\t\t\tAggregateName: \"#{safe}\", BackHref: \"/#{plural}\","
        lines << "\t\t\tItem: #{safe}ShowItem{ID: obj.ID, Fields: fields},"
        lines << "\t\t})"
        lines << "\t})"
        lines << ""
      end
      lines
    end

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

          # GET form
          lines << "\tmux.HandleFunc(\"GET /#{plural}/#{cmd_snake}/new\", func(w http.ResponseWriter, r *http.Request) {"
          lines << "\t\tfields := []FormField{"
          cmd.attributes.each do |a|
            if a == self_id
              lines << "\t\t\t{Type: \"hidden\", Name: \"#{a.name}\", Value: r.URL.Query().Get(\"id\")},"
            elsif a.name.to_s.end_with?("_id")
              ref_name = a.name.to_s.sub(/_id$/, "")
              ref_agg = @domain.aggregates.find { |ra| GoUtils.snake_case(ra.name) == ref_name }
              if ref_agg
                display = ref_agg.attributes.find { |da| da.name.to_s == "name" } ? "Name" : "ID"
                lines << "\t\t\t// #{ref_agg.name} dropdown built dynamically below"
              end
            else
              input_type = case a.type.to_s
                           when /Integer/ then "number"
                           when /Float/ then "number"
                           else "text"
                           end
              label = a.name.to_s.split("_").map(&:capitalize).join(" ")
              lines << "\t\t\t{Type: \"input\", Name: \"#{a.name}\", Label: \"#{label}\", InputType: \"#{input_type}\", Required: true},"
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
      # Collect roles from ports
      all_roles = @domain.aggregates.flat_map { |a| a.ports.keys }.uniq.map(&:to_s)
      all_roles = ["admin"] if all_roles.empty?

      # Collect policies
      policies = @domain.aggregates.flat_map { |a| a.policies.reject { |p| p.respond_to?(:guard?) && p.guard? }.map { |p| "#{p.event_name} → #{p.name}" } }
      policies += @domain.policies.map { |p| "#{p.event_name} → #{p.trigger_command}" }

      lines = []
      lines << "\t// Config"
      lines << "\ttype ConfigAgg struct { Name string; Href string; Count int; Commands string; Ports string }"
      lines << "\ttype ConfigData struct {"
      lines << "\t\tRoles []string; CurrentRole string"
      lines << "\t\tAdapters []string; CurrentAdapter string"
      lines << "\t\tEventCount int; BootedAt string"
      lines << "\t\tPolicies []string; Aggregates []ConfigAgg"
      lines << "\t}"
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
      lines << "\t\t\tEventCount: 0,"
      lines << "\t\t\tBootedAt: \"now\","
      lines << "\t\t\tPolicies: []string{#{policies.map { |p| "\"#{p}\"" }.join(', ')}},"
      lines << "\t\t\tAggregates: aggs,"
      lines << "\t\t})"
      lines << "\t})"
      lines << ""
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
