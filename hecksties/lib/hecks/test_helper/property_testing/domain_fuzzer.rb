# = Hecks::TestHelper::PropertyTesting::DomainFuzzer
#
# Generates random data for every aggregate in a domain, executes create
# commands against a booted runtime, and reports successes and failures.
# Designed for smoke-testing domain models with random inputs.
#
#   domain = Hecks.domain("Pizzas") { ... }
#   runtime = Hecks.load(domain)
#   report = DomainFuzzer.new(domain, runtime).run(iterations: 20)
#   report.passed?        # => true
#   report.summary        # => "20/20 passed across 2 aggregates"
#
module Hecks
  module TestHelper
    module PropertyTesting
      class DomainFuzzer
        attr_reader :domain, :runtime

        # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
        # @param runtime [Hecks::Runtime] a booted runtime with memory adapters
        # @param seed [Integer, nil] random seed for reproducibility
        def initialize(domain, runtime, seed: nil)
          @domain = domain
          @runtime = runtime
          @seed = seed
        end

        # Run the fuzzer against all aggregates.
        #
        # @param iterations [Integer] number of random instances per aggregate
        # @return [FuzzReport] the test report
        def run(iterations: 10)
          results = []
          @domain.aggregates.each do |agg|
            results.concat(fuzz_aggregate(agg, iterations))
          end
          FuzzReport.new(results: results, seed: @seed)
        end

        private

        def fuzz_aggregate(aggregate, iterations)
          gen = AggregateGenerator.new(aggregate, seed: @seed)
          create_cmd = find_create_command(aggregate)
          return [] unless create_cmd

          gen.generate_for_command(create_cmd.name, iterations).map do |attrs|
            fuzz_one(aggregate, create_cmd, attrs)
          end
        end

        def fuzz_one(aggregate, command, attrs)
          @runtime.run(command.name, **attrs)
          FuzzResult.new(
            aggregate: aggregate.name,
            command: command.name,
            attributes: attrs,
            success: true
          )
        rescue StandardError => e
          FuzzResult.new(
            aggregate: aggregate.name,
            command: command.name,
            attributes: attrs,
            success: false,
            error: e
          )
        end

        def find_create_command(aggregate)
          aggregate.commands.find { |c| c.name.start_with?("Create") }
        end
      end

      # Immutable result of a single fuzz attempt.
      class FuzzResult
        attr_reader :aggregate, :command, :attributes, :error

        def initialize(aggregate:, command:, attributes:, success:, error: nil)
          @aggregate = aggregate
          @command = command
          @attributes = attributes
          @success = success
          @error = error
        end

        def success?
          @success
        end
      end

      # Summary report from a full fuzz run.
      class FuzzReport
        attr_reader :results, :seed

        def initialize(results:, seed:)
          @results = results
          @seed = seed
        end

        def passed?
          @results.all?(&:success?)
        end

        def failures
          @results.reject(&:success?)
        end

        def successes
          @results.select(&:success?)
        end

        def summary
          aggs = @results.map(&:aggregate).uniq
          "#{successes.size}/#{@results.size} passed across #{aggs.size} aggregate(s)"
        end

        def failure_details
          failures.map do |f|
            "#{f.aggregate}##{f.command}: #{f.error.class} — #{f.error.message}"
          end
        end
      end
    end
  end
end
