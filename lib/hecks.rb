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

# = Hecks
#
# Top-level entry point for the Hecks domain modeling framework. This module
# serves as the primary public API for loading domains, configuring the runtime,
# managing cross-domain communication, and controlling multi-tenancy/actor context.
#
# Hecks extends itself with several mixins that provide domain inspection,
# building, compiling, event storm importing, visualization, and boot capabilities.
#
# == Architecture
#
# Hecks follows a three-layer architecture:
# - *Domain Model* -- Pure Ruby objects (aggregates, value objects, entities)
#   defined via the Hecks DSL
# - *Ports* -- Commands, queries, repositories, and event bus that mediate
#   between the domain and the outside world
# - *Runtime* -- Wires everything together, manages lifecycle, and provides
#   the +app["AggregateName"]+ accessor pattern
#
# == Module-level State
#
# - +@configuration+ -- The current {Hecks::Configuration} instance (nil until
#   +configure+ is called)
# - +@loaded_domains+ -- Cache of parsed domain objects keyed by domain name
# - +@domain_objects+ -- Cache of compiled domain object classes
# - +@last_domain+ -- The most recently loaded domain (convenience accessor)
# - +@load_strategy+ -- Either +:files+ (default) or +:inline+ for in-memory domains
# - +@extension_registry+ -- Hash of extension name => boot hook proc
# - +@extension_meta+ -- Hash of extension name => metadata hash (description, config, wires_to)
# - +@cross_domain_queries+ -- Hash of query name => {CrossDomainQuery} instance
# - +@cross_domain_views+ -- Hash of view name => {CrossDomainView} instance
#
# == Usage
#
# Plain Ruby (file-based domain):
#
#   domain = Hecks.build { aggregate("Pizza") { attribute :name, String } }
#   app = Hecks.load(domain)
#   app["Pizza"].all
#
# Rails (via initializer):
#
#   Hecks.configure do
#     domain "pizzas_domain"
#     adapter :sql
#   end
#
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

  # Returns the hash of registered extension hooks, keyed by extension name
  # (Symbol). Each value is a Proc that will be called at boot time.
  #
  # @return [Hash{Symbol => Proc}] the extension registry
  def self.extension_registry
    @extension_registry
  end

  # Returns the hash of extension metadata registered via +describe_extension+.
  # Each value is a Hash with keys +:description+, +:config+, and +:wires_to+.
  #
  # @return [Hash{Symbol => Hash}] the extension metadata registry
  def self.extension_meta
    @extension_meta
  end

  # Registers an extension by name with a boot-time hook block. The hook
  # will be called during +Runtime+ initialization, allowing the extension
  # to wire into the runtime (e.g., attach event listeners, start servers).
  #
  # @param name [String, Symbol] the extension name (will be symbolized)
  # @yield the boot-time hook block, called when the runtime starts
  # @return [Proc] the registered hook block
  def self.register_extension(name, &hook)
    @extension_registry[name.to_sym] = hook
  end

  # Registers metadata about an extension for use by the +generate:config+
  # CLI command. This metadata describes what the extension does and what
  # configuration options it accepts.
  #
  # @param name [String, Symbol] the extension name (will be symbolized)
  # @param description [String] human-readable description of the extension
  # @param config [Hash{Symbol => Hash}] configuration options, each with
  #   +:default+ and +:desc+ keys
  # @param wires_to [Symbol, nil] which runtime component this extension
  #   connects to (e.g., +:event_bus+)
  # @return [Hash] the stored metadata hash
  #
  # @example
  #   Hecks.describe_extension(:sockets,
  #     description: "WebSocket server for live domain events",
  #     config: { port: { default: 9293, desc: "WebSocket port" } },
  #     wires_to: :event_bus)
  def self.describe_extension(name, description:, config: {}, wires_to: nil)
    @extension_meta[name.to_sym] = {
      description: description, config: config, wires_to: wires_to
    }
  end

  # Returns the most recently loaded domain object. This is a convenience
  # accessor used by the CLI, session, and playground to refer to "the
  # current domain" without explicitly passing it around.
  #
  # @return [Hecks::DomainModel::Structure::Domain, nil] the last loaded domain
  def self.last_domain
    @last_domain
  end

  # Returns the shared event bus used for cross-domain event routing.
  # This bus is initialized during multi-domain boot and allows events
  # published in one domain to be received by listeners in another.
  #
  # @return [Hecks::FilteredEventBus, nil] the shared event bus, or nil
  #   if not yet initialized
  def self.event_bus
    @shared_event_bus
  end

  # Returns the global async queue, defaulting to an in-memory implementation.
  # The queue is used for background command processing and async workflows.
  #
  # @return [Hecks::Queue::MemoryQueue] the current queue instance
  def self.queue
    @queue ||= Queue::MemoryQueue.new
  end

  # Sets the global async queue to the given instance.
  #
  # @param q [#push, #pop] a queue implementation (must respond to push/pop)
  # @return [Object] the assigned queue
  def self.queue=(q)
    @queue = q
  end

  # Defines a cross-domain query under the given name. Cross-domain queries
  # allow one domain to read data from another domain's repositories without
  # direct coupling.
  #
  # @param name [Symbol, String] the query name used to invoke it later
  # @yield the query definition block, evaluated as a {CrossDomainQuery}
  # @return [Hecks::CrossDomainQuery] the registered query object
  def self.cross_domain_query(name, &block)
    require_relative "hecks/ports/queries/cross_domain_query"
    @cross_domain_queries[name] = CrossDomainQuery.new(name, &block)
  end

  # Executes a previously registered cross-domain query by name.
  #
  # @param name [Symbol, String] the query name (must have been registered
  #   via +cross_domain_query+)
  # @param params [Hash] keyword arguments passed through to the query
  # @return [Object] the query result
  # @raise [Hecks::Error] if no query is registered under the given name
  def self.query(name, **params)
    q = @cross_domain_queries[name]
    raise Error, "Unknown cross-domain query: #{name}" unless q
    q.call(**params)
  end

  # Returns the hash of all registered cross-domain queries.
  #
  # @return [Hash{Symbol => Hecks::CrossDomainQuery}] query name => query object
  def self.cross_domain_queries
    @cross_domain_queries
  end

  # Defines a cross-domain view under the given name. Cross-domain views
  # maintain a denormalized projection of data from multiple domains by
  # subscribing to events on the shared event bus.
  #
  # @param name [Symbol, String] the view name
  # @yield the view definition block, evaluated as a {CrossDomainView}
  # @return [Hecks::CrossDomainView] the registered view object
  def self.cross_domain_view(name, &block)
    require_relative "hecks/ports/event_bus/cross_domain_view"
    view = CrossDomainView.new(name, &block)
    @cross_domain_views[name] = view
    view.subscribe(@shared_event_bus) if @shared_event_bus
    view
  end

  # Returns the hash of all registered cross-domain views.
  #
  # @return [Hash{Symbol => Hecks::CrossDomainView}] view name => view object
  def self.cross_domain_views
    @cross_domain_views
  end

  # Sets the most recently loaded domain object. Called internally by the
  # domain loading pipeline.
  #
  # @param domain [Hecks::DomainModel::Structure::Domain] the domain to set
  # @return [Hecks::DomainModel::Structure::Domain] the assigned domain
  def self.last_domain=(domain)
    @last_domain = domain
  end

  # Returns the current load strategy. Determines how domain source files
  # are resolved during boot.
  #
  # @return [Symbol] either +:files+ (load from disk) or +:inline+ (in-memory DSL)
  def self.load_strategy
    @load_strategy
  end

  # Sets the load strategy.
  #
  # @param strategy [Symbol] either +:files+ (load from disk) or +:inline+
  #   (in-memory DSL)
  # @return [Symbol] the assigned strategy
  def self.load_strategy=(strategy)
    @load_strategy = strategy
  end

  # Returns the current thread-local tenant identifier. Used by the
  # tenancy support extension to scope repository queries.
  #
  # @return [String, nil] the current tenant ID, or nil if unset
  def self.tenant
    Thread.current[:hecks_tenant]
  end

  # Sets the current thread-local tenant identifier.
  #
  # @param tenant_id [String, Symbol, nil] the tenant ID (will be converted
  #   to String; nil clears the tenant)
  # @return [String, nil] the assigned tenant ID
  def self.tenant=(tenant_id)
    Thread.current[:hecks_tenant] = tenant_id&.to_s
  end

  # Executes the block with the given tenant as the active tenant,
  # restoring the previous tenant value afterward. Thread-safe.
  #
  # @param tenant_id [String, Symbol] the tenant ID for the duration of the block
  # @yield the block to execute within the tenant context
  # @return [Object] the return value of the block
  def self.with_tenant(tenant_id)
    old = Thread.current[:hecks_tenant]
    Thread.current[:hecks_tenant] = tenant_id.to_s
    yield
  ensure
    Thread.current[:hecks_tenant] = old
  end

  # Returns the current thread-local actor (user or system identity).
  # Used by the audit extension to record who performed an action.
  #
  # @return [Object, nil] the current actor, or nil if unset
  def self.actor
    Thread.current[:hecks_actor]
  end

  # Sets the current thread-local actor.
  #
  # @param actor [Object] the actor identity (e.g., user object, string ID)
  # @return [Object] the assigned actor
  def self.actor=(actor)
    Thread.current[:hecks_actor] = actor
  end

  # Executes the block with the given actor as the active actor,
  # restoring the previous actor value afterward. Thread-safe.
  #
  # @param actor [Object] the actor identity for the duration of the block
  # @yield the block to execute within the actor context
  # @return [Object] the return value of the block
  def self.with_actor(actor)
    old = Thread.current[:hecks_actor]
    Thread.current[:hecks_actor] = actor
    yield
  ensure
    Thread.current[:hecks_actor] = old
  end

  # Evaluates the given block as configuration DSL and boots the runtime
  # (unless running under Rails, where boot is deferred to the Railtie).
  #
  # The block is evaluated in the context of a new {Configuration} instance,
  # giving access to DSL methods like +domain+, +adapter+, +extension+, etc.
  #
  # @yield the configuration DSL block
  # @return [Hecks::Configuration] the resulting configuration object
  #
  # @example
  #   Hecks.configure do
  #     domain "pizzas_domain"
  #     adapter :sql
  #     extension :audit
  #   end
  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  # Returns the current Configuration object, or nil if +configure+ has
  # not yet been called.
  #
  # @return [Hecks::Configuration, nil] the current configuration
  def self.configuration
    @configuration
  end

  # Loads a domain and wires up the runtime in one step. This is the
  # primary entry point for standalone (non-Rails) applications.
  #
  # Internally calls +load_domain+ to parse and cache the domain definition,
  # then creates a new {Runtime} instance that wires up repositories,
  # command bus, event bus, and all registered extensions.
  #
  # @param domain [Hecks::DomainModel::Structure::Domain] the domain object to load
  # @param force [Boolean] if true, re-parse the domain even if already cached
  # @param opts [Hash] additional options passed to {Runtime#initialize}
  # @yield optional configuration block passed to {Runtime#initialize}
  # @return [Hecks::Runtime] the fully wired runtime instance
  #
  # @example
  #   domain = Hecks.build { aggregate("Pizza") { attribute :name, String } }
  #   app = Hecks.load(domain)
  #   app["Pizza"].create(name: "Margherita")
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
