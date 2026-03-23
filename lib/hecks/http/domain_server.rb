# Hecks::HTTP::DomainServer
#
# WEBrick server that serves a domain as REST + SSE. Generated from the DSL.
#
#   hecks serve pizzas_domain
#
require "webrick"
require "json"
require "stringio"
require "tmpdir"
require_relative "route_builder"

module Hecks
  module HTTP
    class DomainServer
      def initialize(domain, port: 9292)
        @domain = domain
        @port = port
        @sse_clients = []
        boot_domain
      end

      def run
        puts "Hecks serving #{@domain.name} on http://localhost:#{@port}"
        puts ""
        @routes.each { |r| puts "  #{r[:method].ljust(6)} #{r[:path]}" }
        puts "  GET    /events (SSE)"
        puts ""

        server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
        server.mount_proc("/") { |req, res| handle(req, res) }
        trap("INT") { server.shutdown }
        server.start
      end

      private

      def handle(req, res)
        set_cors(res)
        return if req.request_method == "OPTIONS"

        if req.path == "/events"
          # SSE not supported in basic WEBrick — return event list instead
          res["Content-Type"] = "application/json"
          res.body = JSON.generate(@app.events.map { |e| { type: e.class.name.split("::").last, occurred_at: e.occurred_at.iso8601 } })
          return
        end

        route = @routes.find { |r| r[:method] == req.request_method && match?(r[:path], req.path) }
        unless route
          res.status = 404
          res["Content-Type"] = "application/json"
          res.body = JSON.generate(error: "Not found")
          return
        end

        wrapper = RequestWrapper.new(req)
        result = route[:handler].call(wrapper)
        res["Content-Type"] = "application/json"
        res.body = JSON.generate(result)
      rescue => e
        res.status = 422
        res["Content-Type"] = "application/json"
        res.body = JSON.generate(error: e.message)
      end

      def boot_domain
        tmpdir = Dir.mktmpdir("hecks_serve")
        gem_path = Hecks.build(@domain, output_dir: tmpdir)
        lib_path = File.join(gem_path, "lib")
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        require @domain.gem_name
        Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| require f }
        @mod = Object.const_get(@domain.module_name + "Domain")
        @app = Services::Application.new(@domain)
        @routes = RouteBuilder.new(@domain, @mod).build
      end

      def match?(pattern, path)
        pp = pattern.split("/"); ap = path.split("/")
        pp.size == ap.size && pp.zip(ap).all? { |p, a| p.start_with?(":") || p == a }
      end

      def set_cors(res)
        res["Access-Control-Allow-Origin"] = "*"
        res["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS"
        res["Access-Control-Allow-Headers"] = "Content-Type"
      end

      # Wraps WEBrick::HTTPRequest to look like Rack::Request for RouteBuilder
      class RequestWrapper
        attr_reader :path, :params

        def initialize(req)
          @req = req
          @path = req.path
          @params = req.query
        end

        def body
          ::StringIO.new(@req.body || "")
        end

        def request_method
          @req.request_method
        end
      end
    end
  end
end
