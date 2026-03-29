require "hecks"
require "tmpdir"

Hecks.load_strategy = :memory
require_relative "support/shared_boot"

# Track constants hoisted to Object by Hecks::Runtime
# so we can clean them up between specs.
HECKS_HOISTED = []

module Hecks
  class Runtime
    private

    alias_method :_original_hoist_constants, :hoist_constants

    def hoist_constants
      _original_hoist_constants
      @domain.aggregates.each { |a| HECKS_HOISTED << a.name.to_sym }
    end
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
  config.order = :random

  config.after(:each) do
    HECKS_HOISTED.each { |name| Hecks::Utils.remove_constant(name) }
    HECKS_HOISTED.clear
    Hecks::Utils.remove_constant(:APP)
  end
end
