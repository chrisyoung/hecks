# Hecks::Benchmarks
#
# Entry point for the benchmark subsystem. Measures build, load, and
# dispatch performance with monotonic timing and regression detection.
#
#   Hecks::Benchmarks.run_all(domain_dir: "examples/pizzas")
#
module Hecks
  module Benchmarks
    autoload :Timer,             "hecks/benchmarks/timer"
    autoload :BuildBenchmark,    "hecks/benchmarks/build_benchmark"
    autoload :LoadBenchmark,     "hecks/benchmarks/load_benchmark"
    autoload :DispatchBenchmark, "hecks/benchmarks/dispatch_benchmark"
    autoload :ResultStore,       "hecks/benchmarks/result_store"

    SUITES = %i[build load dispatch].freeze

    # Run all benchmark suites and return combined results.
    #
    # @param domain_dir [String] path to a directory with a Bluebook
    # @param iterations [Integer] number of iterations per suite
    # @return [Hash] keyed by suite name
    def self.run_all(domain_dir:, iterations: 10)
      results = {}
      SUITES.each do |suite|
        klass = const_get("#{suite.capitalize}Benchmark")
        results[suite] = klass.run(domain_dir: domain_dir, iterations: iterations)
      end
      results
    end
  end
end
