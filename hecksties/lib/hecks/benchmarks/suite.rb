module Hecks
  module Benchmarks

    # Hecks::Benchmarks::Suite
    #
    # Runs build, load, and dispatch benchmarks against a domain.
    # Each benchmark is run +iterations+ times and the median is reported.
    # Returns a Hash with timing results suitable for JSON serialization.
    #
    #   suite = Suite.new(domain_path: "examples/pizzas")
    #   results = suite.run
    #   results[:build_ms]    # => 5.23
    #   results[:dispatch_ms] # => 0.12
    #
    class Suite
      ITERATIONS = 5
      REGRESSION_THRESHOLD = 0.20

      # @param domain_path [String] path to a directory containing a Bluebook
      # @param iterations [Integer] number of iterations per benchmark
      def initialize(domain_path:, iterations: ITERATIONS)
        @domain_path = domain_path
        @iterations = iterations
      end

      # Run all benchmarks and return results.
      #
      # @return [Hash] benchmark results with :build_ms, :load_ms, :dispatch_ms,
      #   :iterations, :timestamp, and :domain keys
      def run
        {
          domain: File.basename(@domain_path),
          timestamp: Time.now.iso8601,
          iterations: @iterations,
          build_ms: benchmark_build,
          load_ms: benchmark_load,
          dispatch_ms: benchmark_dispatch
        }
      end

      # Compare results against a baseline and return regressions.
      #
      # @param current [Hash] current benchmark results
      # @param baseline [Hash] previous benchmark results
      # @return [Array<String>] regression warnings (empty if none)
      def self.check_regressions(current, baseline)
        warnings = []
        %i[build_ms load_ms dispatch_ms].each do |key|
          cur = current[key]
          base = baseline[key]
          next unless cur && base && base > 0
          ratio = (cur - base) / base
          if ratio > REGRESSION_THRESHOLD
            warnings << "#{key} regressed by #{"%.0f" % (ratio * 100)}% (#{format_ms(base)} -> #{format_ms(cur)})"
          end
        end
        warnings
      end

      def self.format_ms(ms)
        "#{"%.2f" % ms}ms"
      end

      private

      def benchmark_build
        bluebook_file = find_bluebook
        return nil unless bluebook_file

        times = @iterations.times.map do
          elapsed, _ = Timer.measure { eval(File.read(bluebook_file), TOPLEVEL_BINDING, bluebook_file) }
          elapsed
        end
        median(times)
      end

      def benchmark_load
        bluebook_file = find_bluebook
        return nil unless bluebook_file

        times = @iterations.times.map do
          elapsed, _ = Timer.measure do
            domain = eval(File.read(bluebook_file), TOPLEVEL_BINDING, bluebook_file)
            Hecks::Validator.new(domain).valid?
          end
          elapsed
        end
        median(times)
      end

      def benchmark_dispatch
        bluebook_file = find_bluebook
        return nil unless bluebook_file

        domain = eval(File.read(bluebook_file), TOPLEVEL_BINDING, bluebook_file)
        return nil if domain.aggregates.empty? || domain.aggregates.first.commands.empty?

        app = Hecks.load(domain)
        agg = domain.aggregates.first
        cmd = agg.commands.first

        attrs = cmd.attributes.each_with_object({}) do |a, h|
          h[a.name] = sample_value(a.type)
        end

        # Warm up
        app.run(cmd.name, **attrs) rescue nil

        times = @iterations.times.map do
          elapsed, _ = Timer.measure { app.run(cmd.name, **attrs) rescue nil }
          elapsed
        end
        median(times)
      end

      def find_bluebook
        Dir[File.join(@domain_path, "*Bluebook")].first
      end

      def median(times)
        sorted = times.sort
        mid = sorted.size / 2
        sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
      end

      def sample_value(type)
        case type.to_s
        when "Integer" then 1
        when "Float"   then 1.0
        when "Boolean" then true
        when "Date"    then Date.today
        else "benchmark_sample"
        end
      end
    end
  end
end
