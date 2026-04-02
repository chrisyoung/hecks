# = Hecks::ContractTesting
#
# Test harness for verifying that repository adapters conform to the
# Hecks repository interface contract. Provides shared RSpec examples
# that exercise find, save, delete, all, count, query, and clear --
# ensuring any adapter (memory, SQL, filesystem, MongoDB, etc.) behaves
# identically.
#
# Also includes a spec generator that writes contract specs for every
# aggregate in a domain, so adapter authors get compliance tests for free.
#
# == Usage (manual)
#
#   require "hecks/contract_testing"
#
#   RSpec.describe MyAdapter do
#     include_examples "hecks repository contract",
#       adapter: -> { MyAdapter.new },
#       factory: -> { MyDomain::Pizza.new(name: "Test") }
#   end
#
# == Usage (auto-generate)
#
#   Hecks::ContractTesting.generate_specs(domain, output_dir: "spec/contracts")
#
require_relative "contract_testing/repository_contract"
require_relative "contract_testing/spec_generator"

module Hecks
  module ContractTesting
    # Generates contract spec files for every aggregate in a domain.
    #
    # Delegates to SpecGenerator to produce one spec file per aggregate,
    # each including the shared "hecks repository contract" examples.
    #
    # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
    # @param output_dir [String] directory to write spec files into
    # @return [Array<String>] list of generated file paths
    def self.generate_specs(domain, output_dir:)
      SpecGenerator.new(domain, output_dir: output_dir).generate
    end
  end
end
