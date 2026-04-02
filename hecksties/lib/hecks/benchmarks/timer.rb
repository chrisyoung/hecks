# Hecks::Benchmarks::Timer
#
# Monotonic-clock timer that runs a block N times and computes
# min, median, and max durations in seconds.
#
#   result = Hecks::Benchmarks::Timer.measure(iterations: 10) { some_work }
#   result[:median] # => 0.0032
#
module Hecks
  module Benchmarks
    class Timer
      # Run a block N times and return timing statistics.
      #
      # @param iterations [Integer] number of runs
      # @yield the block to benchmark
      # @return [Hash] :min, :median, :max, :times (all in seconds)
      def self.measure(iterations: 10)
        times = Array.new(iterations) do
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          yield
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        end

        sorted = times.sort
        mid = iterations / 2
        median = iterations.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0

        { min: sorted.first, median: median, max: sorted.last, times: times }
      end
    end
  end
end
