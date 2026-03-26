require "hecks"
require "tmpdir"

# Build and install each component gem at test startup to catch packaging errors early
root = File.expand_path("..", __dir__)
Dir.mktmpdir do |dir|
  %w[hecksties hecks_model hecks_domain hecks_runtime hecks_session hecks_cli hecks_persist].each do |component|
    gemspec = File.join(root, component, "#{component}.gemspec")
    next unless File.exist?(gemspec)
    gem_path = "#{dir}/#{component}.gem"
    output = `gem build #{gemspec} -o #{gem_path} 2>&1`
    abort "Gem build failed for #{component}!\n#{output}" unless $?.success?
    output = `gem install #{gem_path} 2>&1`
    abort "Gem install failed for #{component}!\n#{output}" unless $?.success?
  end
end
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
    HECKS_HOISTED.each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name)
    end
    HECKS_HOISTED.clear
    Object.send(:remove_const, :APP) if Object.const_defined?(:APP)
  end
end
