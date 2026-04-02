# Hecks::Benchmarks::BuildBenchmark
#
# Measures the time to build a domain gem from a Bluebook file.
# Uses the default :ruby target and writes to a temp directory.
#
#   result = Hecks::Benchmarks::BuildBenchmark.run(domain_dir: "examples/pizzas")
#   result[:median] # => 0.045
#
require "tmpdir"

module Hecks
  module Benchmarks
    class BuildBenchmark
      # @param domain_dir [String] directory containing a Bluebook
      # @param iterations [Integer] number of timed runs
      # @return [Hash] timing stats from Timer
      def self.run(domain_dir:, iterations: 10)
        bluebook = Dir[File.join(domain_dir, "*Bluebook")].first
        raise "No Bluebook found in #{domain_dir}" unless bluebook

        Kernel.load(bluebook)
        domain = Hecks.last_domain
        domain.source_path = bluebook

        Timer.measure(iterations: iterations) do
          Dir.mktmpdir do |tmp|
            Hecks.build(domain, output_dir: tmp)
          end
        end
      end
    end
  end
end
