# = Hecks::TestHelper::PropertyTesting
#
# Property-based testing toolkit for Hecks domains. Generates random valid
# data from domain IR metadata and runs fuzz tests against booted runtimes.
# No external gems required.
#
#   require "hecks/test_helper/property_testing"
#
#   gen = Hecks::TestHelper::PropertyTesting::AggregateGenerator.new(pizza_agg)
#   gen.generate(10).each { |attrs| puts attrs.inspect }
#
#   fuzzer = Hecks::TestHelper::PropertyTesting::DomainFuzzer.new(domain, runtime)
#   report = fuzzer.run(iterations: 50)
#   puts report.summary
#
require_relative "property_testing/type_generators"
require_relative "property_testing/aggregate_generator"
require_relative "property_testing/domain_fuzzer"
require_relative "property_testing/rspec_integration"

module Hecks
  module TestHelper
    module PropertyTesting
    end
  end
end
