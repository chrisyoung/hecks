# Hecks::HTTP::DomainServer
#
# Rack app that serves a domain as REST + SSE. Generated from the DSL.
#
#   hecks serve pizzas_domain
#
require "rack"
require "json"
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
        Rack::Handler::WEBrick.run(method(:call), Port: @port,
          Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
      end

      def call(env)
        req = Rack::Request.new(env)
        return cors_preflight if req.request_method == "OPTIONS"
        return sse_stream if req.path == "/events"
        route = @routes.find { |r| r[:method] == req.request_method && match?(r[:path], req.path) }
        return json(404, error: "Not found") unless route
        json(200, route[:handler].call(req))
      rescue => e
        json(422, error: e.message)
      end

      private

      def boot_domain
        tmpdir = Dir.mktmpdir("hecks_serve")
        gem_path = Hecks.build(@domain, output_dir: tmpdir)
        lib_path = File.join(gem_path, "lib")
        $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
        require @domain.gem_name
        Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
        @mod = Object.const_get(@domain.module_name + "Domain")
        @app = Services::Application.new(@domain)
        @routes = RouteBuilder.new(@domain, @mod).build
        @domain.aggregates.flat_map { |a| a.events.map(&:name) }.uniq.each do |evt|
          @app.event_bus.subscribe(evt) { |e| broadcast(e) }
        end
      end

      def match?(pattern, path)
        pp = pattern.split("/"); ap = path.split("/")
        pp.size == ap.size && pp.zip(ap).all? { |p, a| p.start_with?(":") || p == a }
      end

      def sse_stream
        q = Queue.new
        @sse_clients << q
        body = proc do |out|
          out.call("data: {\"connected\":true}\n\n")
          loop { out.call("data: #{q.pop}\n\n") }
        rescue IOError
          @sse_clients.delete(q)
        end
        [200, { "Content-Type" => "text/event-stream", "Cache-Control" => "no-cache", "Access-Control-Allow-Origin" => "*" }, body]
      end

      def broadcast(event)
        data = JSON.generate(type: event.class.name.split("::").last, occurred_at: event.occurred_at.iso8601)
        @sse_clients.each { |q| q << data rescue nil }
      end

      def json(status, data)
        [status, cors_headers.merge("Content-Type" => "application/json"), [JSON.generate(data)]]
      end

      def cors_preflight
        [204, cors_headers, []]
      end

      def cors_headers
        { "Access-Control-Allow-Origin" => "*", "Access-Control-Allow-Methods" => "GET, POST, PATCH, DELETE, OPTIONS", "Access-Control-Allow-Headers" => "Content-Type" }
      end
    end
  end
end
