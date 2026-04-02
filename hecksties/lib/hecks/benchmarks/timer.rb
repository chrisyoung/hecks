module Hecks
  module Benchmarks

    # Hecks::Benchmarks::Timer
    #
    # Measures elapsed wall-clock time for a block in milliseconds.
    # Uses Process.clock_gettime for monotonic precision.
    #
    #   elapsed, result = Timer.measure { expensive_operation }
    #   elapsed  # => 12.34 (ms)
    #
    class Timer
      # Measures the wall-clock time of the given block.
      #
      # @return [Array(Float, Object)] elapsed milliseconds and block return value
      def self.measure
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        [(finish - start) * 1000.0, result]
      end
    end
  end
end
