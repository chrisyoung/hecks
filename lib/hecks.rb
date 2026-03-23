# Hecks — Top-level entry point for the Hecks framework.
#
require "json"

# Suppress json-schema MultiJSON deprecation from mcp gem
JSON::Validator.use_multi_json = false if defined?(JSON::Validator)

module Hecks
  class PortAccessDenied < StandardError; end
end

require_relative "hecks/autoloads"
require_relative "hecks/domain_inspector"
require_relative "hecks/domain_builder_methods"
require_relative "hecks/domain_compiler"
require_relative "hecks/event_storm_importer"

module Hecks
  extend DomainInspector
  extend DomainBuilderMethods
  extend DomainCompiler
  extend EventStormImporter

  @configuration = nil
  @loaded_domains = {}
  @domain_objects = {}

  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  def self.configuration
    @configuration
  end

  require "active_hecks/railtie" if defined?(::Rails::Railtie)
end
