require_relative "server_generator/data_routes"
require_relative "server_generator/ui_routes"

# HecksGo::ServerGenerator
#
# Generates a Go HTTP server using net/http with JSON API routes and
# HTML UI routes rendered via html/template.
#
module HecksGo
  class ServerGenerator
    include GoUtils
    include DataRoutes
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
      vc = Hecks::ViewContracts
      lines << "\t#{vc.go_struct(:home_agg, vc::HOME[:structs][:home_agg])}"
      lines << "\t#{vc.go_struct(:home_data, vc::HOME[:fields])}"
      lines << "\tmux.HandleFunc(\"GET /{$}\", func(w http.ResponseWriter, r *http.Request) {"
      lines << "\t\trenderer.Render(w, \"home\", \"#{@domain.name}Domain\", HomeData{"
      lines << "\t\t\tDomainName: \"#{@domain.name}Domain\", Aggregates: []HomeAgg{#{agg_data.join(', ')}},"
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
