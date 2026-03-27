require "fileutils"

# HecksGo::ProjectGenerator
#
# Generates a complete Go project from a domain IR. Produces domain
# structs, commands, events, ports (interfaces), memory adapters,
# HTTP server, go.mod, and a main.go entry point.
#
#   gen = ProjectGenerator.new(domain, output_dir: "examples")
#   gen.generate  # => path to generated Go project
#
module HecksGo
  class ProjectGenerator
    include GoUtils

    def initialize(domain, output_dir: ".")
      @domain = domain
      @output_dir = output_dir
    end

    def generate
      name = GoUtils.snake_case(@domain.name)
      @root = File.join(@output_dir, "#{name}_go")
      @module_path = "#{name}_domain"
      FileUtils.mkdir_p(@root)

      generate_go_mod
      generate_domain
      generate_adapters
      generate_server
      generate_main

      @root
    end

    private

    def write(path, content)
      full = File.join(@root, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
    end

    def generate_go_mod
      write("go.mod", <<~MOD)
        module #{@module_path}

        go 1.21

        require github.com/google/uuid v1.6.0
      MOD
    end

    def generate_domain
      @domain.aggregates.each do |agg|
        # Aggregate
        gen = AggregateGenerator.new(agg, package: "domain")
        write("domain/#{GoUtils.snake_case(agg.name)}.go", gen.generate)

        # Value objects
        agg.value_objects.each do |vo|
          gen = ValueObjectGenerator.new(vo, package: "domain")
          write("domain/#{GoUtils.snake_case(vo.name)}.go", gen.generate)
        end

        # Port (repository interface)
        gen = PortGenerator.new(agg, package: "domain")
        write("domain/#{GoUtils.snake_case(agg.name)}_repository.go", gen.generate)

        # Commands
        agg.commands.each_with_index do |cmd, i|
          event = agg.events[i]
          gen = CommandGenerator.new(cmd, aggregate: agg, event: event, package: "domain")
          write("domain/#{GoUtils.snake_case(cmd.name)}.go", gen.generate)
        end

        # Events
        agg.events.each do |evt|
          gen = EventGenerator.new(evt, aggregate: agg, package: "domain")
          write("domain/#{GoUtils.snake_case(evt.name)}.go", gen.generate)
        end
      end

      # Errors
      gen = ErrorsGenerator.new(package: "domain")
      write("domain/errors.go", gen.generate)
    end

    def generate_adapters
      @domain.aggregates.each do |agg|
        gen = MemoryAdapterGenerator.new(agg, package: "memory", domain_package: @module_path)
        write("adapters/memory/#{GoUtils.snake_case(agg.name)}_repository.go", gen.generate)
      end
    end

    def generate_server
      gen = ServerGenerator.new(@domain, module_path: @module_path)
      write("server/server.go", gen.generate)
    end

    def generate_main
      lines = []
      lines << "package main"
      lines << ""
      lines << "import ("
      lines << "\t\"fmt\""
      lines << "\t\"os\""
      lines << "\t\"strconv\""
      lines << "\t\"#{@module_path}/server\""
      lines << ")"
      lines << ""
      lines << "func main() {"
      lines << "\tport := 9292"
      lines << "\tif p := os.Getenv(\"PORT\"); p != \"\" {"
      lines << "\t\tif v, err := strconv.Atoi(p); err == nil { port = v }"
      lines << "\t}"
      lines << "\tif len(os.Args) > 1 {"
      lines << "\t\tif v, err := strconv.Atoi(os.Args[1]); err == nil { port = v }"
      lines << "\t}"
      lines << "\tapp := server.NewApp()"
      lines << "\tif err := app.Start(port); err != nil {"
      lines << "\t\tfmt.Fprintf(os.Stderr, \"Error: %v\\n\", err)"
      lines << "\t\tos.Exit(1)"
      lines << "\t}"
      lines << "}"
      write("cmd/#{GoUtils.snake_case(@domain.name)}/main.go", lines.join("\n") + "\n")
    end
  end
end
