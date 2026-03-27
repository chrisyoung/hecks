module HecksStandalone
# Hecks::Generators::Standalone::ServerGenerator
#
# Generates a domain-specific HTTP server subclass with routes derived
# from the domain IR. Each aggregate gets GET / and GET /:id routes.
# Each command gets a POST route. The server also mounts a GET /_openapi
# endpoint that returns a minimal API description.
#
#   gen = ServerGenerator.new(domain)
#   gen.generate("PizzasDomain", "pizzas_domain")
#
class ServerGenerator
  def initialize(domain)
    @domain = domain
  end

  def generate(mod, gem_name)
    lines = []
    lines << "require_relative \"../runtime/errors\""
    lines << "require_relative \"server\""
    lines << "require_relative \"ui_routes\""
    lines << ""
    lines << "module #{mod}"
    lines << "  module Server"
    lines << "    class DomainApp < App"
    lines << "      include UIRoutes"
    lines << ""
    lines << "      private"
    lines << ""
    lines << "      def mount_routes(server)"
    lines.concat(route_lines)
    lines.concat(openapi_route(mod))
    lines << "        mount_ui_routes(server)"
    lines << "      end"
    lines << "    end"
    lines << "  end"
    lines << "end"
    lines.join("\n") + "\n"
  end

  private

  def route_lines
    lines = []
    @domain.aggregates.each do |agg|
      safe = Hecks::Utils.sanitize_constant(agg.name)
      snake = Hecks::Utils.underscore(safe)
      plural = snake + "s"
      plural = snake if snake.end_with?("s")

      # GET /pizzas — list all
      lines << "        server.mount_proc \"/#{plural}\" do |req, res|"
      lines << "          if req.request_method == \"GET\""
      lines << "            items = #{safe}.all.map { |obj| aggregate_to_hash(obj) }"
      lines << "            json_response(res, items)"
      lines << "          else"
      lines << "            res.status = 405"
      lines << "          end"
      lines << "        end"
      lines << ""

      # GET /pizzas/:id — find by ID
      lines << "        server.mount_proc \"/#{plural}/find\" do |req, res|"
      lines << "          id = req.query[\"id\"]"
      lines << "          obj = #{safe}.find(id)"
      lines << "          if obj"
      lines << "            json_response(res, aggregate_to_hash(obj))"
      lines << "          else"
      lines << "            json_error(res, { error: \"NotFound\", message: \"#{safe} not found\" }, status: 404)"
      lines << "          end"
      lines << "        end"
      lines << ""

      # POST /pizzas/:command — one route per command
      agg.commands.each do |cmd|
        cmd_snake = Hecks::Utils.underscore(cmd.name)
        lines << "        server.mount_proc \"/#{plural}/#{cmd_snake}\" do |req, res|"
        lines << "          begin"
        lines << "            attrs = parse_body(req)"
        lines << "            error = #{@domain.module_name}Domain::Validations.check(\"#{safe}\", \"#{cmd_snake}\", attrs)"
        lines << "            raise error if error"
        lines << "            result = #{safe}.#{cmd_snake}(**attrs)"
        lines << "            json_response(res, aggregate_to_hash(result.aggregate), status: 201)"
        lines << "          rescue #{@domain.module_name}Domain::Error => e"
        lines << "            json_error(res, e)"
        lines << "          end"
        lines << "        end"
        lines << ""
      end
    end
    lines
  end

  def openapi_route(mod)
    paths = {}
    @domain.aggregates.each do |agg|
      safe = Hecks::Utils.sanitize_constant(agg.name)
      snake = Hecks::Utils.underscore(safe)
      plural = snake + "s"
      plural = snake if snake.end_with?("s")

      paths["/#{plural}"] = { "get" => { "summary" => "List all #{plural}" } }
      paths["/#{plural}/find"] = { "get" => { "summary" => "Find #{safe} by ID" } }

      agg.commands.each do |cmd|
        cmd_snake = Hecks::Utils.underscore(cmd.name)
        params = cmd.attributes.map { |a| { "name" => a.name.to_s, "type" => (a.type || "string").to_s } }
        paths["/#{plural}/#{cmd_snake}"] = {
          "post" => { "summary" => cmd.name, "parameters" => params }
        }
      end
    end

    spec = { "openapi" => "3.0.0", "info" => { "title" => mod }, "paths" => paths }

    [
      "        server.mount_proc \"/_openapi\" do |req, res|",
      "          json_response(res, #{spec.inspect})",
      "        end",
      "",
      "        server.mount_proc \"/_validations\" do |req, res|",
      "          json_response(res, #{@domain.module_name}Domain::Validations.rules || {})",
      "        end"
    ]
  end

end
end
