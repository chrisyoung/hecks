require "stringio"
require "bluebook"

module Hecks
  class Workshop
    class WebRunner
      # Hecks::Workshop::WebRunner::CommandParser
      #
      # Safe command dispatcher for the web console. Uses BlueBook::Grammar
      # to parse input, then dispatches to ConsoleRunner or AggregateHandle
      # methods. No eval — only whitelisted commands execute.
      #
      #   CommandParser.new(runner).execute("Pizza.attr :name, String")
      #   # => { output: "name attribute added to Pizza", error: nil }
      #
      class CommandParser
        def initialize(runner, web_runner: nil)
          @runner = runner
          @web_runner = web_runner
        end

        def execute(input)
          old_stdout = $stdout
          $stdout = StringIO.new
          begin
            result = dispatch(input.strip)
            captured = $stdout.string
            if captured.empty? && !result.nil? && !result.is_a?(Hecks::Workshop::AggregateHandle)
              captured += result.inspect
            end
            { output: captured, error: nil }
          rescue => e
            { output: $stdout.string, error: "#{e.class}: #{e.message}" }
          ensure
            $stdout = old_stdout
          end
        end

        private

        def dispatch(input)
          return nil if input.empty?
          parsed = BlueBook::Grammar.parse(input)

          if parsed[:error]
            puts parsed[:error]
            return nil
          end

          target = parsed[:target]
          method = parsed[:method]
          args   = parsed[:args]
          kwargs = parsed[:kwargs]

          # Bare command (no target)
          if target.nil?
            if method == "reset!" && @web_runner && !@runner.instance_variable_get(:@workshop).play?
              return @web_runner.reload_domain!
            end
            if method == "diagram"
              ws = @runner.instance_variable_get(:@workshop)
              serializer = Hecks::Workshop::WebRunner::StateSerializer.new(ws)
              state = serializer.serialize
              puts state[:mermaid]
              return nil
            end
            return @runner.send(method)
          end

          # Aggregate name alone — describe if it exists, create if it doesn't
          if method.nil?
            ws = @runner.instance_variable_get(:@workshop)
            if ws.aggregate_builders.key?(target)
              return ws.aggregate(target).describe
            else
              return @runner.aggregate(target)
            end
          end

          # Handle method
          handle = @runner.aggregate(target)
          if kwargs.any?
            handle.send(method, *args, **kwargs)
          else
            handle.send(method, *args)
          end
        end
      end
    end
  end
end
