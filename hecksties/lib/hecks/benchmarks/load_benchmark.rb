# Hecks::Benchmarks::LoadBenchmark
#
# Measures the time to load a domain from a Bluebook and wire a
# runtime with in-memory adapters (no persistence).
#
#   result = Hecks::Benchmarks::LoadBenchmark.run(domain_dir: "examples/pizzas")
#   result[:median] # => 0.012
#
module Hecks
  module Benchmarks
    class LoadBenchmark
      # @param domain_dir [String] directory containing a Bluebook
      # @param iterations [Integer] number of timed runs
      # @return [Hash] timing stats from Timer
      def self.run(domain_dir:, iterations: 10)
        bluebook = Dir[File.join(domain_dir, "*Bluebook")].first
        raise "No Bluebook found in #{domain_dir}" unless bluebook

        Timer.measure(iterations: iterations) do
          Kernel.load(bluebook)
          domain = Hecks.last_domain
          domain.source_path = bluebook
          Hecks.load(domain, force: true)
        end
      end
    end
  end
end
