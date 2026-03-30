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

      attr_reader :domain_path

      def initialize(name: nil, port: 4567, domain: nil)
        @port        = port
        @domain_path = domain
        @runner = ConsoleRunner.new(name: name)
        if domain
          @runner.instance_variable_set(:@workshop, load_domain_file(domain))
        else
          @runner.instance_variable_set(:@workshop, @runner.setup_workshop)
        end
        @evaluator  = Evaluator.new(@runner, web_runner: self)
        @serializer = StateSerializer.new(workshop)
      end

      def reload_domain!
        if @domain_path
          @runner.instance_variable_set(:@workshop, load_domain_file(@domain_path))
        else
          name = workshop.name
          @runner.instance_variable_set(:@workshop, Hecks::Workshop.new(name))
        end
        @serializer = StateSerializer.new(workshop)
        puts "Reset to #{@domain_path ? 'loaded domain' : 'empty workshop'}"
      end

      def run
        server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
                                          AccessLog: [])
        server.mount_proc("/") { |req, res| handle(req, res) }
        trap("INT") { server.shutdown }
        puts "Hecks Web Console: http://localhost:#{@port}"
        server.start
      end

      def workshop
        @runner.instance_variable_get(:@workshop)
      end

      private

      def handle(req, res)
        case [req.request_method, req.path]
        when ["GET",  "/"]      then serve_console(res)
        when ["POST", "/eval"]  then serve_eval(req, res)
        when ["GET",  "/state"] then serve_state(res)
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
        end
        puts "Loaded domain from #{path}: #{domain.name}"
        ws
      end
    end
  end
end
