# Hecks
#
# Top-level entry point for the Hecks domain modeling framework.
# Extends itself with DomainInspector, DomainBuilderMethods, DomainCompiler,
# EventStormImporter, and DomainVisualizerMethods. Manages global configuration
# via Hecks.configure and auto-loads the ActiveHecks Railtie when Rails
# is present.
#
# Plain Ruby:
#
#   app = Hecks.load(domain)
#   app["Pizza"].all
#   Pizza.create(name: "Margherita")
#
# Rails (via initializer):
#
#   Hecks.configure do
#     domain "pizzas_domain"
#     adapter :sql
#   end
#
require "json"

# Suppress json-schema MultiJSON deprecation from mcp gem
JSON::Validator.use_multi_json = false if defined?(JSON::Validator)

require_relative "hecks/errors"
require_relative "hecks/autoloads"
require_relative "hecks/domain_inspector"
require_relative "hecks/domain_builder_methods"
require_relative "hecks/domain_compiler"
require_relative "hecks/in_memory_loader"
require_relative "hecks/event_storm_importer"
require_relative "hecks/domain_visualizer_methods"
require_relative "hecks/boot"

module Hecks
  extend DomainInspector
  extend DomainBuilderMethods
  extend DomainCompiler
  extend EventStormImporter
  extend DomainVisualizerMethods
  extend Boot

  @configuration = nil
  @loaded_domains = {}
  @domain_objects = {}
  @last_domain = nil
  @load_strategy = :files
  @connection_registry = {}

  def self.connection_registry
    @connection_registry
  end

  def self.register_connection(name, &hook)
    @connection_registry[name.to_sym] = hook
  end

  def self.last_domain
    @last_domain
  end

  def self.last_domain=(domain)
    @last_domain = domain
  end

  def self.load_strategy
    @load_strategy
  end

  def self.load_strategy=(strategy)
    @load_strategy = strategy
  end

  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  def self.configuration
    @configuration
  end

  # Load a domain and wire up the runtime in one step.
  # Returns a Hecks::Runtime instance.
  #
  #   app = Hecks.load(domain)
  #   Pizza.create(name: "Margherita")
  #
  def self.load(domain, force: false, **opts, &config)
    load_domain(domain, force: force)
    Runtime.new(domain, **opts, &config)
  end

  require "active_hecks/railtie" if defined?(::Rails::Railtie)
end
