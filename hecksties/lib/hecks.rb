require "json"
require "date"
require "ostruct"

# Suppress json-schema MultiJSON deprecation from mcp gem
JSON::Validator.use_multi_json = false if defined?(JSON::Validator)

require_relative "hecks/errors"
require_relative "hecks/autoloads"
require "hecks_templating"
require "hecks_multidomain"
require "hecks_explorer"
require "hecks/domain/inspector"
require "hecks/domain/builder_methods"
require "hecks/domain/compiler"
require "hecks/domain/in_memory_loader"
require "hecks/domain/event_storm_importer"
require "hecks/domain/visualizer_methods"
require "hecks/runtime/boot"

require_relative "hecks/registries/extension_registry"
require_relative "hecks/registries/domain_registry"
require_relative "hecks/registries/cross_domain"
require_relative "hecks/registries/thread_context"

# = Hecks
#
# Top-level entry point for the Hecks domain modeling framework.
# Extends focused registry modules instead of holding all state directly.
#
module Hecks
  extend DomainInspector
  extend DomainBuilderMethods
  extend DomainCompiler
  extend EventStormImporter
  extend DomainVisualizerMethods
  extend Boot
  extend ExtensionRegistryMethods
  extend DomainRegistryMethods
  extend CrossDomainMethods
  extend ThreadContextMethods

  @configuration = nil
  @loaded_domains = {}
  @domain_objects = {}
  @last_domain = nil
  @load_strategy = :memory
  @extension_registry = {}
  @extension_meta = {}
  @cross_domain_queries = {}
  @cross_domain_views = {}

  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  def self.configuration
    @configuration
  end

  def self.load(domain, force: false, **opts, &config)
    load_domain(domain, force: force)
    Runtime.new(domain, **opts, &config)
  end

  if defined?(::Rails::Railtie)
    begin
      require "active_hecks/railtie"
    rescue LoadError
      # active_hecks gem not installed
    end
  end
end
