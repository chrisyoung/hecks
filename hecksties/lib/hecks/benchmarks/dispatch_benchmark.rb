# Hecks::Benchmarks::DispatchBenchmark
#
# Measures the time to dispatch commands through a booted runtime.
# Loads the domain once, then times N create-command dispatches.
#
#   result = Hecks::Benchmarks::DispatchBenchmark.run(domain_dir: "examples/pizzas")
#   result[:median] # => 0.0004
#
module Hecks
  module Benchmarks
    class DispatchBenchmark
      # @param domain_dir [String] directory containing a Bluebook
      # @param iterations [Integer] number of timed runs
      # @return [Hash] timing stats from Timer
      def self.run(domain_dir:, iterations: 10)
        bluebook = Dir[File.join(domain_dir, "*Bluebook")].first
        raise "No Bluebook found in #{domain_dir}" unless bluebook

        Kernel.load(bluebook)
        domain = Hecks.last_domain
        domain.source_path = bluebook
        runtime = Hecks.load(domain, force: true)

        aggregate = domain.aggregates.first
        command = aggregate.commands.first
        attrs = build_sample_attrs(command)

        Timer.measure(iterations: iterations) do
          runtime.run(command.name, **attrs)
        end
      end

      # Build minimal sample attributes for a command.
      # Strings get "bench", Integers get 1, Booleans get true, etc.
      def self.build_sample_attrs(command)
        command.attributes.each_with_object({}) do |attr, hash|
          hash[attr.name.to_sym] = sample_value(attr)
        end
      end

      def self.sample_value(attr)
        case attr.type.to_s
        when /Integer/i then 1
        when /Float/i   then 1.0
        when /Boolean/i then true
        when /Date/i    then Date.today.to_s
        else                 "bench_#{attr.name}"
        end
      end
    end
  end
end
