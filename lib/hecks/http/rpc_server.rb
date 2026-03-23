# Hecks::HTTP::RpcServer
#
# JSON-RPC server generated from a domain. One endpoint, method dispatch.
#
#   hecks serve pizzas_domain --rpc
#
#   {"method": "CreatePizza", "params": {"name": "Margherita"}, "id": 1}
#   {"method": "Pizza.find", "params": {"id": "abc-123"}, "id": 2}
#   {"method": "Pizza.classics", "params": {}, "id": 3}
#
require "rack"
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
        Rack::Handler::WEBrick.run(method(:call), Port: @port,
          Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
      end

      def call(env)
        req = Rack::Request.new(env)
        return cors_preflight if req.request_method == "OPTIONS"

        body = req.body.read
        return error_response(nil, -32700, "Parse error") if body.empty?

        request = JSON.parse(body)
        method_name = request["method"]
        params = request["params"] || {}
        id = request["id"]

        handler = @methods[method_name]
        return error_response(id, -32601, "Method not found: #{method_name}") unless handler

        result = handler.call(params)
        success_response(id, result)
      rescue JSON::ParserError
        error_response(nil, -32700, "Parse error")
      rescue => e
        error_response(request&.dig("id"), -32000, e.message)
      end

      private

      def boot_domain
        tmpdir = Dir.mktmpdir("hecks_rpc")
        gem_path = Hecks.build(@domain, output_dir: tmpdir)
        lib_path = File.join(gem_path, "lib")
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        require @domain.gem_name
        Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
        @mod = Object.const_get(@domain.module_name + "Domain")
        @app = Services::Application.new(@domain)
      end

      def register_methods
        @domain.aggregates.each do |agg|
          klass = @mod.const_get(agg.name)
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
        obj.class.instance_method(:initialize).parameters.each_with_object({}) do |(_, n), h|
          h[n.to_s] = obj.send(n) if n && obj.respond_to?(n)
        end
      end

      def success_response(id, result)
        json(200, jsonrpc: "2.0", result: result, id: id)
      end

      def error_response(id, code, message)
        json(200, jsonrpc: "2.0", error: { code: code, message: message }, id: id)
      end

      def json(status, data)
        [status, cors_headers.merge("Content-Type" => "application/json"), [JSON.generate(data)]]
      end

      def cors_preflight
        [204, cors_headers, []]
      end

      def cors_headers
        { "Access-Control-Allow-Origin" => "*",
          "Access-Control-Allow-Methods" => "POST, OPTIONS",
          "Access-Control-Allow-Headers" => "Content-Type" }
      end
    end
  end
end
