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
require "date"
require "ostruct"

# Suppress json-schema MultiJSON deprecation from mcp gem
JSON::Validator.use_multi_json = false if defined?(JSON::Validator)

require_relative "hecks/errors"
require_relative "hecks/autoloads"
require_relative "hecks/domain/inspector"
require_relative "hecks/domain/builder_methods"
require_relative "hecks/domain/compiler"
require_relative "hecks/domain/in_memory_loader"
require_relative "hecks/domain/event_storm_importer"
require_relative "hecks/domain/visualizer_methods"
require_relative "hecks/runtime/boot"

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
  @extension_registry = {}
  @extension_meta = {}
  @cross_domain_queries = {}
  @cross_domain_views = {}

  def self.extension_registry
    @extension_registry
  end

  def self.extension_meta
    @extension_meta
  end

  def self.register_extension(name, &hook)
    @extension_registry[name.to_sym] = hook
  end

  # Extensions call this to describe their config for generate:config.
  #
  #   Hecks.describe_extension(:sockets,
  #     description: "WebSocket server for live domain events",
  #     config: { port: { default: 9293, desc: "WebSocket port" } },
  #     wires_to: :event_bus)
  #
  def self.describe_extension(name, description:, config: {}, wires_to: nil)
    @extension_meta[name.to_sym] = {
      description: description, config: config, wires_to: wires_to
    }
  end

  def self.last_domain
    @last_domain
  end

  def self.event_bus
    @shared_event_bus
  end

  def self.queue
    @queue ||= Queue::MemoryQueue.new
  end

  def self.queue=(q)
    @queue = q
  end

  def self.cross_domain_query(name, &block)
    require_relative "hecks/ports/queries/cross_domain_query"
    @cross_domain_queries[name] = CrossDomainQuery.new(name, &block)
  end

  def self.query(name, **params)
    q = @cross_domain_queries[name]
    raise Error, "Unknown cross-domain query: #{name}" unless q
    q.call(**params)
  end

  def self.cross_domain_queries
    @cross_domain_queries
  end

  def self.cross_domain_view(name, &block)
    require_relative "hecks/ports/event_bus/cross_domain_view"
    view = CrossDomainView.new(name, &block)
    @cross_domain_views[name] = view
    view.subscribe(@shared_event_bus) if @shared_event_bus
    view
  end

  def self.cross_domain_views
    @cross_domain_views
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

  def self.tenant
    Thread.current[:hecks_tenant]
  end

  def self.tenant=(tenant_id)
    Thread.current[:hecks_tenant] = tenant_id&.to_s
  end

  def self.with_tenant(tenant_id)
    old = Thread.current[:hecks_tenant]
    Thread.current[:hecks_tenant] = tenant_id.to_s
    yield
  ensure
    Thread.current[:hecks_tenant] = old
  end

  def self.actor
    Thread.current[:hecks_actor]
  end

  def self.actor=(actor)
    Thread.current[:hecks_actor] = actor
  end

  def self.with_actor(actor)
    old = Thread.current[:hecks_actor]
    Thread.current[:hecks_actor] = actor
    yield
  ensure
    Thread.current[:hecks_actor] = old
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

  if defined?(::Rails::Railtie)
    begin
      require "active_hecks/railtie"
    rescue LoadError
      # active_hecks gem not installed
    end
  end
end
