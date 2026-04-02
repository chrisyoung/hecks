module Hecks
  module PropertyTesting

    # Hecks::PropertyTesting::DomainFuzzer
    #
    # Fuzzes an entire domain by generating random commands and dispatching
    # them. Catches crashes, invariant violations, and unexpected exceptions.
    # Reports a summary of successes and failures.
    #
    #   fuzzer = DomainFuzzer.new(domain, seed: 42, rounds: 50)
    #   report = fuzzer.run
    #   report[:successes]  # => 45
    #   report[:failures]   # => [{command: "CreatePizza", error: "..."}]
    #
    class DomainFuzzer
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain to fuzz
      # @param seed [Integer] random seed for reproducibility
      # @param rounds [Integer] number of random commands to dispatch
      def initialize(domain, seed: Random.new_seed, rounds: 50)
        @domain = domain
        @seed = seed
        @rounds = rounds
        @rng = Random.new(seed)
      end

      # Run the fuzzer and return a report.
      #
      # @return [Hash] with :seed, :rounds, :successes, :failures keys
      def run
        app = Hecks.load(@domain)
        generators = build_generators
        return empty_report if generators.empty?

        successes = 0
        failures = []

        @rounds.times do
          agg_name, gen, cmd = pick_command(generators)
          attrs = gen.command_attrs(cmd.name)

          begin
            app.run(cmd.name, **attrs)
            successes += 1
          rescue => e
            failures << {
              command: cmd.name,
              aggregate: agg_name,
              attrs: attrs,
              error: "#{e.class}: #{e.message}"
            }
          end
        end

        { seed: @seed, rounds: @rounds, successes: successes, failures: failures }
      end

      private

      def build_generators
        @domain.aggregates.flat_map do |agg|
          next [] if agg.commands.empty?
          seed = @rng.rand(0..1_000_000)
          gen = AggregateGenerator.new(agg, seed: seed)
          agg.commands.map { |cmd| [agg.name, gen, cmd] }
        end
      end

      def pick_command(generators)
        generators[@rng.rand(generators.size)]
      end

      def empty_report
        { seed: @seed, rounds: @rounds, successes: 0, failures: [] }
      end
    end
  end
end
