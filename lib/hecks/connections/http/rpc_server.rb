# Hecks::HTTP::RpcServer
#
# WEBrick-based JSON-RPC 2.0 server for a domain. Single POST endpoint that
# dispatches to commands, queries, and CRUD methods per aggregate. Boots the
# domain gem from a temp directory, same as DomainServer.
#
#   hecks domain serve pizzas_domain --rpc
#
require "webrick"
require "json"
require "tmpdir"

module Hecks
  module HTTP
    class RpcServer
      def initialize(domain, port: 9292)
        @domain = domain
        @port = port
        @methods = {}
        boot_domain
        register_methods
      end

      def run
        puts "Hecks RPC serving #{@domain.name} on http://localhost:#{@port}"
        puts ""
        puts "Methods:"
        @methods.each_key { |m| puts "  #{m}" }
        puts ""

        server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
        server.mount_proc("/") { |req, res| handle(req, res) }
        trap("INT") { server.shutdown }
        server.start
      end

      private

      def handle(req, res)
        res["Access-Control-Allow-Origin"] = "*"
        res["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        res["Access-Control-Allow-Headers"] = "Content-Type"
        res["Content-Type"] = "application/json"
        return if req.request_method == "OPTIONS"

        body = req.body || ""
        if body.empty?
          res.body = JSON.generate(jsonrpc: "2.0", error: { code: -32700, message: "Parse error" }, id: nil)
          return
        end

        request = JSON.parse(body)
        method_name = request["method"]
        params = request["params"] || {}
        id = request["id"]

        handler = @methods[method_name]
        unless handler
          res.body = JSON.generate(jsonrpc: "2.0", error: { code: -32601, message: "Method not found: #{method_name}" }, id: id)
          return
        end

        result = handler.call(params)
        res.body = JSON.generate(jsonrpc: "2.0", result: result, id: id)
      rescue JSON::ParserError
        res.body = JSON.generate(jsonrpc: "2.0", error: { code: -32700, message: "Parse error" }, id: nil)
      rescue => e
        res.body = JSON.generate(jsonrpc: "2.0", error: { code: -32000, message: e.message }, id: request&.dig("id"))
      end

      def boot_domain
        mod_name = @domain.module_name + "Domain"
        unless Object.const_defined?(mod_name)
          tmpdir = Dir.mktmpdir("hecks_rpc")
          gem_path = Hecks.build(@domain, output_dir: tmpdir)
          lib_path = File.join(gem_path, "lib")
          $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
          require @domain.gem_name
          Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| require f }
        end
        @mod = Object.const_get(mod_name)
        @app = Services::Runtime.new(@domain)
      end

      def register_methods
        @domain.aggregates.each do |agg|
          klass = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
          register_commands(agg, klass)
          register_queries(agg, klass)
          register_crud(agg, klass)
        end
      end

      def register_commands(agg, klass)
        agg.commands.each do |cmd|
          method_name = Hecks::Utils.underscore(cmd.name)
            .sub(/_#{Hecks::Utils.underscore(agg.name)}$/, "").to_sym
          @methods[cmd.name] = ->(params) {
            serialize(klass.send(method_name, **params.transform_keys(&:to_sym)))
          }
        end
      end

      def register_queries(agg, klass)
        agg.queries.each do |query|
          qn = Hecks::Utils.underscore(query.name)
          params = query.block.parameters
          @methods["#{agg.name}.#{qn}"] = ->(p) {
            args = params.map { |_, name| p[name.to_s] }
            results = params.empty? ? klass.send(qn.to_sym) : klass.send(qn.to_sym, *args)
            results.respond_to?(:map) ? results.map { |r| serialize(r) } : results
          }
        end
      end

      def register_crud(agg, klass)
        name = agg.name
        @methods["#{name}.find"] = ->(p) {
          result = klass.find(p["id"])
          result ? serialize(result) : (raise "Not found")
        }
        @methods["#{name}.all"] = ->(_) { klass.all.map { |r| serialize(r) } }
        @methods["#{name}.count"] = ->(_) { klass.count }
        @methods["#{name}.delete"] = ->(p) { klass.delete(p["id"]); { deleted: p["id"] } }
      end

      def serialize(obj)
        Hecks::Utils.serialize_object(obj)
      end
    end
  end
end
