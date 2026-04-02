# Hecks::Benchmarks::ResultStore
#
# Persists benchmark results as JSON in tmp/benchmarks/ and detects
# regressions by comparing median times against the previous run.
# A 20% increase in median time triggers a regression warning.
#
#   store = Hecks::Benchmarks::ResultStore.new
#   store.save(results)
#   store.check_regressions(results) # => [{ suite: :build, ... }]
#
require "json"
require "fileutils"

module Hecks
  module Benchmarks
    class ResultStore
      REGRESSION_THRESHOLD = 0.20
      DEFAULT_DIR = "tmp/benchmarks"

      attr_reader :dir

      def initialize(dir: DEFAULT_DIR)
        @dir = dir
      end

      # Save results to a timestamped JSON file.
      #
      # @param results [Hash] suite => timing hash
      # @return [String] path to saved file
      def save(results)
        FileUtils.mkdir_p(dir)
        filename = "benchmark_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
        path = File.join(dir, filename)
        payload = results.transform_values { |v| v.except(:times) }
        File.write(path, JSON.pretty_generate(payload))
        path
      end

      # Load the most recent saved result.
      #
      # @return [Hash, nil] parsed results or nil if none exist
      def latest
        files = Dir[File.join(dir, "benchmark_*.json")].sort
        return nil if files.empty?

        JSON.parse(File.read(files.last), symbolize_names: true)
      end

      # Compare current results against the previous run.
      # Returns an array of regression hashes for any suite whose
      # median increased by more than REGRESSION_THRESHOLD (20%).
      #
      # @param current [Hash] suite => timing hash
      # @return [Array<Hash>] regressions found
      def check_regressions(current)
        previous = latest
        return [] unless previous

        regressions = []
        current.each do |suite, timing|
          prev = previous[suite]
          next unless prev && prev[:median]

          pct_change = (timing[:median] - prev[:median]) / prev[:median]
          next unless pct_change > REGRESSION_THRESHOLD

          regressions << {
            suite: suite,
            previous_median: prev[:median],
            current_median: timing[:median],
            pct_change: (pct_change * 100).round(1)
          }
        end
        regressions
      end
    end
  end
end
