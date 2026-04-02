# = Hecks::TestHelper::PropertyTesting::RSpecIntegration
#
# RSpec matchers and helpers for property-based testing. Provides
# `survive_fuzz_testing` matcher and `property_test` helper method
# for concise property assertions in specs.
#
#   RSpec.describe "Pizza domain" do
#     include Hecks::TestHelper::PropertyTesting::RSpecHelpers
#
#     it "survives fuzz testing" do
#       expect(domain_with_runtime).to survive_fuzz_testing(iterations: 50)
#     end
#
#     it "always produces valid names" do
#       property_test(aggregate, count: 20) do |attrs|
#         expect(attrs[:name]).to be_a(String)
#       end
#     end
#   end
#
module Hecks
  module TestHelper
    module PropertyTesting
      module RSpecHelpers
        # Run a property assertion against N random attribute hashes.
        #
        # @param aggregate [Hecks::DomainModel::Structure::Aggregate] the aggregate IR
        # @param count [Integer] number of random samples
        # @param seed [Integer, nil] random seed
        # @yield [Hash] each generated attribute hash
        def property_test(aggregate, count: 20, seed: nil, &block)
          gen = AggregateGenerator.new(aggregate, seed: seed)
          gen.generate(count).each(&block)
        end
      end

      # RSpec matcher: expect(domain_with_runtime).to survive_fuzz_testing
      class SurviveFuzzTestingMatcher
        def initialize(iterations:, seed:)
          @iterations = iterations
          @seed = seed
        end

        def matches?(domain_runtime_pair)
          domain, runtime = domain_runtime_pair
          fuzzer = DomainFuzzer.new(domain, runtime, seed: @seed)
          @report = fuzzer.run(iterations: @iterations)
          @report.passed?
        end

        def failure_message
          lines = ["Fuzz testing failed (seed: #{@report.seed}):"]
          lines.concat(@report.failure_details.map { |d| "  - #{d}" })
          lines.join("\n")
        end

        def description
          "survive #{@iterations} iterations of fuzz testing"
        end
      end
    end
  end
end

if defined?(RSpec)
  RSpec::Matchers.define :survive_fuzz_testing do |iterations: 10, seed: nil|
    matcher = Hecks::TestHelper::PropertyTesting::SurviveFuzzTestingMatcher.new(
      iterations: iterations, seed: seed
    )

    match { |actual| matcher.matches?(actual) }
    failure_message { matcher.failure_message }
    description { matcher.description }
  end
end
