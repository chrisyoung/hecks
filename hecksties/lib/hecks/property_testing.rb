# Hecks::PropertyTesting
#
# Property-based testing support for Hecks domains. Generates random
# valid inputs for domain types, aggregates, and commands. No external
# gems required -- uses Ruby's built-in Random with seeded randomness.
#
#   gen = Hecks::PropertyTesting::TypeGenerator.new(seed: 42)
#   gen.string  # => "qxkw"
#   gen.integer # => 7291
#
module Hecks
  module PropertyTesting
    autoload :TypeGenerator,      "hecks/property_testing/type_generator"
    autoload :AggregateGenerator, "hecks/property_testing/aggregate_generator"
    autoload :DomainFuzzer,       "hecks/property_testing/domain_fuzzer"
  end
end
