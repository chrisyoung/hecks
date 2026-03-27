# HecksGo::ServerGenerator
#
# Generates a Go HTTP server using net/http with JSON API routes.
# One POST per command, GET for list/find per aggregate, plus /_openapi.
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
      lines << "\t\"#{@module_path}/domain\""
      lines << "\t\"#{@module_path}/adapters/memory\""
      lines << ")"
      lines << ""

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

      lines << "func (app *App) Start(port int) error {"
      lines << "\tmux := http.NewServeMux()"
      lines << ""
      lines.concat(route_lines)
      lines << "\taddr := fmt.Sprintf(\":%d\", port)"
      lines << "\tfmt.Printf(\"Serving on http://localhost%s\\n\", addr)"
      lines << "\treturn http.ListenAndServe(addr, mux)"
      lines << "}"
      lines << ""

      lines.concat(helper_methods)

      lines.join("\n") + "\n"
    end

    private

    def route_lines
      lines = []
      @domain.aggregates.each do |agg|
        safe = agg.name
        snake = GoUtils.snake_case(safe)
        plural = snake + "s"

        # GET /pizzas
        lines << "\tmux.HandleFunc(\"GET /#{plural}\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\titems, _ := app.#{safe}Repo.All()"
        lines << "\t\tjsonResponse(w, items)"
        lines << "\t})"
        lines << ""

        # GET /pizzas/find?id=
        lines << "\tmux.HandleFunc(\"GET /#{plural}/find\", func(w http.ResponseWriter, r *http.Request) {"
        lines << "\t\tid := r.URL.Query().Get(\"id\")"
        lines << "\t\titem, _ := app.#{safe}Repo.Find(id)"
        lines << "\t\tif item == nil {"
        lines << "\t\t\thttp.Error(w, `{\"error\":\"not found\"}`, 404)"
        lines << "\t\t\treturn"
        lines << "\t\t}"
        lines << "\t\tjsonResponse(w, item)"
        lines << "\t})"
        lines << ""

        # POST per command
        agg.commands.each do |cmd|
          cmd_snake = GoUtils.snake_case(cmd.name)
          lines << "\tmux.HandleFunc(\"POST /#{plural}/#{cmd_snake}\", func(w http.ResponseWriter, r *http.Request) {"
          lines << "\t\tvar cmd domain.#{cmd.name}"
          lines << "\t\tif err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {"
          lines << "\t\t\thttp.Error(w, `{\"error\":\"invalid json\"}`, 400)"
          lines << "\t\t\treturn"
          lines << "\t\t}"
          lines << "\t\tagg, _, err := cmd.Execute(app.#{safe}Repo)"
          lines << "\t\tif err != nil {"
          lines << "\t\t\tjsonError(w, err)"
          lines << "\t\t\treturn"
          lines << "\t\t}"
          lines << "\t\tw.WriteHeader(201)"
          lines << "\t\tjsonResponse(w, agg)"
          lines << "\t})"
          lines << ""
        end
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
