require "webrick"
require "json"
require_relative "web_runner/evaluator"
require_relative "web_runner/command_parser"
require_relative "web_runner/state_serializer"

module Hecks
  class Workshop
    # Hecks::Workshop::WebRunner
    #
    # Browser-based REPL for the Hecks Workshop. Starts a WEBrick server
    # that serves a terminal-like console page with side panels for the
    # domain tree and event log. Commands are parsed as a safe command
    # language — no eval, no arbitrary code execution.
    #
    #   WebRunner.new(name: "Pizzas").run
    #   # => opens http://localhost:4567 with the web console
    #
    class WebRunner
      VIEWS_DIR = File.join(__dir__, "web_runner", "views")

      attr_reader :domain_path, :domain_paths, :domain_groups

      def initialize(name: nil, port: 4567, domain: nil, domains: nil)
        @port        = port
        @domain_path = domain
        @domain_paths = domains
        @workshop_name = name
        @domain_groups = {}
        @runner = ConsoleRunner.new(name: name)
        if domains
          ws = load_multi_domain(domains, name)
          @runner.instance_variable_set(:@workshop, ws)
        elsif domain
          @runner.instance_variable_set(:@workshop, load_domain_file(domain))
        else
          @runner.instance_variable_set(:@workshop, @runner.setup_workshop)
        end
        @evaluator  = Evaluator.new(@runner, web_runner: self)
        @serializer = StateSerializer.new(workshop, domain_groups: @domain_groups)
      end

      def reload_domain!
        @domain_groups = {}
        if @domain_paths
          @runner.instance_variable_set(:@workshop, load_multi_domain(@domain_paths, @workshop_name))
        elsif @domain_path
          @runner.instance_variable_set(:@workshop, load_domain_file(@domain_path))
        else
          name = workshop.name
          @runner.instance_variable_set(:@workshop, Hecks::Workshop.new(name))
        end
        @serializer = StateSerializer.new(workshop, domain_groups: @domain_groups)
        puts "Reset to #{@domain_paths ? 'loaded domains' : @domain_path ? 'loaded domain' : 'empty workshop'}"
      end

      BASE = "/hecks_web_workbench"

      def run
        server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
                                          AccessLog: [])
        server.mount_proc("/") { |req, res| handle(req, res) }
        trap("INT") { server.shutdown }
        puts "Hecks Web Console: http://localhost:#{@port}#{BASE}"
        server.start
      end

      def workshop
        @runner.instance_variable_get(:@workshop)
      end

      private

      def handle(req, res)
        case [req.request_method, req.path]
        when ["GET",  BASE]                then serve_console(res)
        when ["POST", "#{BASE}/eval"]      then serve_eval(req, res)
        when ["GET",  "#{BASE}/state"]     then serve_state(res)
        when ["GET",  "#{BASE}/js/components.js"] then serve_js(res, "js/components.js")
        else
          res.status = 404
          res.body = "Not found"
        end
      end

      def serve_console(res)
        template = File.read(File.join(VIEWS_DIR, "console.erb"))
        res.content_type = "text/html"
        res["Cache-Control"] = "no-cache, no-store"
        res.body = ERB.new(template).result(binding)
      end

      def reload_code!
        %w[
          web_runner/command_parser
          web_runner/evaluator
          web_runner/state_serializer
        ].each do |f|
          load File.join(__dir__, "#{f}.rb")
        end
        load File.join(__dir__, "..", "..", "..", "..", "bluebook", "lib", "bluebook", "grammar.rb") rescue nil
        load File.join(__dir__, "..", "..", "..", "..", "bluebook", "lib", "bluebook", "tokenizer.rb") rescue nil
      end

      def serve_eval(req, res)
        reload_code! if ENV["HECKS_DEV"]
        input = JSON.parse(req.body)["input"].to_s.strip
        result = @evaluator.evaluate(input)
        state  = @serializer.serialize
        res.content_type = "application/json"
        res.body = JSON.generate(output: result[:output], error: result[:error], state: state)
      end

      def serve_js(res, path)
        file = File.join(VIEWS_DIR, path)
        res.content_type = "application/javascript"
        res["Cache-Control"] = "no-cache, no-store"
        res.body = File.read(file)
      end

      def serve_state(res)
        res.content_type = "application/json"
        res.body = JSON.generate(@serializer.serialize)
      end

      def load_domain_file(path)
        Kernel.load(File.expand_path(path))
        domain = Hecks.last_domain
        ws = Hecks::Workshop.new(domain.name)
        domain.aggregates.each do |agg|
          ws.aggregate_builders[agg.name] =
            Hecks::DSL::AggregateRebuilder.from_aggregate(agg)
          @domain_groups[agg.name] = domain.name
        end
        puts "Loaded domain from #{path}: #{domain.name}"
        ws
      end

      def load_multi_domain(paths, name)
        ws = Hecks::Workshop.new(name || "Multi")
        paths.each do |path|
          Kernel.load(File.expand_path(path))
          domain = Hecks.last_domain
          domain.aggregates.each do |agg|
            ws.aggregate_builders[agg.name] =
              Hecks::DSL::AggregateRebuilder.from_aggregate(agg)
            @domain_groups[agg.name] = domain.name
          end
          puts "Loaded domain: #{domain.name} (#{domain.aggregates.map(&:name).join(', ')})"
        end
        ws
      end
    end
  end
end
