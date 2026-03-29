require "fileutils"
require "hecks_persist/database_connection"
require_relative "configuration/domain_loader"
require "hecks_persist/sql_setup"

module Hecks
  # Hecks::Configuration
  #
  # Wires Hecks into an application. Supports single or multiple domains with
  # pluggable adapters (memory or SQL). Extensions can be auto-wired or
  # explicitly declared. The auto_wire DSL detects available extensions and
  # enables them declaratively.
  #
  #   # Auto-wire everything:
  #   Hecks.configure do
  #     domain "pizzas_domain"
  #     auto_wire
  #   end
  #
  #   # Auto-wire with overrides:
  #   Hecks.configure do
  #     domain "pizzas_domain"
  #     auto_wire except: [:pii]
  #     extension :sockets, port: 4000
  #   end
  #
  #   # Fully explicit:
  #   Hecks.configure do
  #     domain "pizzas_domain"
  #     adapter :sqlite
  #     extension :http, port: 9292
  #     extension :audit
  #   end
  #
  # Manages the full configuration and boot lifecycle for Hecks applications,
  # particularly in Rails or gem-based setups where +Hecks.configure+ is used
  # instead of +Hecks.boot+. Provides a DSL for declaring domains, adapters,
  # extensions, and async handlers, then boots everything via +#boot!+.
  #
  # Supports:
  # - Multiple domain gems with optional version pinning and local paths
  # - Cross-domain event directionality via +listens_to+ / +sends_to+
  # - Persistence adapters (memory, SQLite, Postgres, MySQL)
  # - Extension auto-wiring with opt-out/opt-in filtering
  # - Ad-hoc query support
  # - Async event handler registration
  # - Rails integration via +active_hecks+ gem
  class Configuration
    include Hecks::NamingHelpers
    include DatabaseConnection
    include DomainLoader
    include SqlSetup

    # @return [Hash<String, Hecks::Runtime>] map of gem_name to Runtime for each booted domain
    attr_reader :apps

    # Initializes a blank configuration with memory adapter defaults.
    # No domains are registered, no extensions are enabled, and persistence
    # is set to in-memory.
    def initialize
      @domains = []
      @adapter_type = :memory
      @adapter_options = {}
      @apps = {}
      @ad_hoc_queries = false
      @extensions = {}
      @extensions_explicit = false
    end

    # Registers a domain gem to be loaded and wired at boot time.
    # Accepts an optional block for declaring cross-domain event directionality
    # using +listens_to+ and +sends_to+.
    #
    # @param gem_name [String] the name of the domain gem (e.g., "pizzas_domain")
    # @param version [String, nil] optional gem version constraint
    # @param path [String, nil] optional local path to the domain directory (builds gem on the fly)
    # @yield optional block for declaring event directionality
    # @return [void]
    #
    # @example Simple domain registration
    #   domain "pizzas_domain"
    #
    # @example With local path
    #   domain "pizzas_domain", path: "domains/pizzas"
    #
    # @example With cross-domain directionality
    #   domain "orders_domain" do
    #     listens_to "inventory_domain"
    #     sends_to "notifications_domain"
    #   end
    def domain(gem_name, version: nil, path: nil, &block)
      entry = { gem_name: gem_name, version: version, path: path }
      if block
        builder = DomainConfigBuilder.new
        builder.instance_eval(&block)
        entry[:listens_to] = builder.listens
        entry[:sends_to] = builder.sends
      end
      @domains << entry
    end

    # DSL helper for domain block -- collects extend declarations.
    # Instances are created internally by +#domain+ when a block is given.
    class DomainConfigBuilder
      # @return [Array<String>] list of source domain names this domain listens to
      attr_reader :listens

      # @return [Array<String>] list of target domain names this domain sends events to
      attr_reader :sends

      def initialize
        @listens = []
        @sends = []
      end

      # Declares that this domain listens to events from the given source domain.
      #
      # @param source [String] the gem name of the source domain
      # @return [void]
      def listens_to(source)
        @listens << source
      end

      # Declares that this domain sends events to the given target domain.
      #
      # @param target [String] the gem name of the target domain
      # @return [void]
      def sends_to(target)
        @sends << target
      end

      # Unified extend — delegates to listens_to/sends_to based on argument.
      def extend(target, *args, **kwargs)
        if target.is_a?(String) || target.is_a?(Module)
          listens_to(target)
        else
          sends_to(target.to_s)
        end
      end
    end

    # Sets the persistence adapter type and options. All domains registered
    # in this configuration will use this adapter unless overridden per-aggregate.
    #
    # @param type [Symbol] adapter type: +:memory+, +:sqlite+, +:postgres+, +:mysql+, +:mysql2+
    # @param options [Hash] adapter-specific options (e.g., +event_sourced: true+, +path: "db.sqlite"+)
    # @return [void]
    def adapter(type, **options)
      @adapter_type = type
      @adapter_options = options
    end

    # Enables ad-hoc query support on all aggregates. When enabled, aggregate
    # classes gain +.where+, +.find_by+, and similar query methods that delegate
    # to the underlying repository.
    #
    # @return [void]
    def include_ad_hoc_queries
      @ad_hoc_queries = true
    end

    # Declaratively auto-wire all detected extensions. Scans the extension registry
    # for available (installed) extensions and enables them with their default config.
    # Use +except:+ to exclude specific extensions, or +only:+ to include only specific ones.
    # Persistence extensions are always excluded (handled separately via +adapter+).
    #
    # @param except [Array<Symbol>] extension names to exclude from auto-wiring
    # @param only [Array<Symbol>, nil] if provided, only these extensions are enabled
    # @return [void]
    #
    # @example Enable all detected extensions
    #   auto_wire
    #
    # @example Exclude PII extension
    #   auto_wire except: [:pii]
    #
    # @example Only enable HTTP and audit
    #   auto_wire only: [:http, :audit]
    def auto_wire(except: [], only: nil)
      @extensions_explicit = true
      require_relative "load_extensions"
      LoadExtensions.require_auto

      Hecks.extension_registry.each_key do |name|
        next if Boot::PERSISTENCE_EXTENSIONS.include?(name)
        next if except.map(&:to_sym).include?(name)
        next if only && !only.map(&:to_sym).include?(name)
        meta = Hecks.extension_meta[name]
        defaults = meta ? meta[:config].transform_values { |v| v[:default] } : {}
        @extensions[name] = defaults unless @extensions.key?(name)
      end
    end

    # Explicitly enable a single extension with optional configuration.
    # If +auto_wire+ was also called, this overrides the auto-detected defaults
    # for this specific extension.
    #
    # @param name [Symbol, String] the extension name (e.g., +:http+, +:audit+, +:sockets+)
    # @param options [Hash] extension-specific configuration options
    # @return [void]
    #
    # @example Enable HTTP extension on a custom port
    #   extension :http, port: 9292
    def extension(name, **options)
      @extensions_explicit = true
      @extensions[name.to_sym] = options
    end

    # Returns whether extensions were explicitly declared via +auto_wire+ or +extension+,
    # as opposed to relying on the default auto-detection behavior.
    #
    # @return [Boolean] true if extensions were explicitly configured
    def extensions_explicit?
      @extensions_explicit
    end

    # Returns the hash of enabled extensions and their configuration options.
    #
    # @return [Hash<Symbol, Hash>] map of extension name to options hash
    def extensions
      @extensions
    end

    # Registers an async handler block for event processing. Policies marked
    # +async: true+ in the domain DSL will use this handler to schedule
    # deferred work (e.g., enqueuing a Sidekiq job).
    #
    # @yield [event] block that handles async event delivery
    # @return [void]
    def async(&block)
      @async_handler = block
    end

    # Loads all registered domains, wires adapters and extensions, and sets
    # the global +APP+ constant to the first booted Runtime. This is the
    # terminal step of the configuration DSL.
    #
    # The boot sequence:
    # 1. Creates a shared event bus for cross-domain communication
    # 2. Connects to the database if using SQL adapter
    # 3. Builds directionality declarations from domain configs
    # 4. Boots each domain (loads gem, creates Runtime, wires adapters)
    # 5. Sets +Object::APP+ to the first Runtime
    # 6. Activates Rails integration if Rails is defined
    #
    # @return [void]
    def boot!
      @shared_event_bus = EventBus.new
      @db = connect_database if @adapter_type == :sql
      @declarations = build_declarations
      @domains.each { |d| boot_domain(d) }
      first_app = @apps.values.first
      old = $VERBOSE; $VERBOSE = nil
      Object.const_set(:APP, first_app) if first_app
      $VERBOSE = old
      activate_rails if defined?(::Rails)
    end

    # Returns the domain IR object of the first registered app.
    # Useful for introspecting the domain structure after boot.
    #
    # @return [Hecks::DomainModel::Structure::Domain, nil] the first domain object, or nil if no apps
    def domain_obj
      @apps.values.first&.domain
    end

    # Returns the first registered Runtime app. Convenience accessor
    # when only one domain is configured.
    #
    # @return [Hecks::Runtime, nil] the first Runtime, or nil if no apps
    def app
      @apps.values.first
    end

    private

    # Builds a hash of gem_name -> array of source gem names from +listens_to+ declarations.
    # Used to create FilteredEventBus instances for cross-domain event filtering.
    #
    # @return [Hash<String, Array<String>>] directionality declarations
    def build_declarations
      decl = {}
      @domains.each do |d|
        next unless d[:listens_to]&.any?
        decl[d[:gem_name]] = d[:listens_to].map(&:to_s)
      end
      decl
    end

    # Returns an event bus for a specific domain. If directionality declarations
    # exist, returns a FilteredEventBus that only passes events from allowed sources.
    # Otherwise returns the shared event bus directly.
    #
    # @param gem_name [String] the domain gem name
    # @return [Hecks::FilteredEventBus, Hecks::EventBus] the appropriate event bus
    def event_bus_for(gem_name)
      if @declarations.any?
        FilteredEventBus.new(
          inner: @shared_event_bus,
          domain_gem_name: gem_name,
          allowed_sources: @declarations[gem_name]
        )
      else
        @shared_event_bus
      end
    end

    # Boots a single domain: loads its gem, creates a Runtime with appropriate
    # adapters, wires event sourcing and ad-hoc queries if configured, and
    # stores the Runtime in +@apps+.
    #
    # @param d [Hash] domain entry with :gem_name, :version, :path, :listens_to, :sends_to
    # @return [void]
    def boot_domain(d)
      domain_obj, domain_module = load_domain(d)
      mod = domain_module_name(domain_obj.name)
      Hecks.instance_variable_get(:@domain_objects)[mod] = domain_obj
      generate_adapters(domain_obj) if @adapter_type == :sql

      adapter_type = @adapter_type
      db = @db
      bus = event_bus_for(d[:gem_name])

      app = Runtime.new(domain_obj, event_bus: bus) do
        if adapter_type == :sql
          domain_obj.aggregates.each do |agg|
            safe_name = Hecks::Utils.sanitize_constant(agg.name)
            adapter_class = domain_module::Adapters.const_get("#{safe_name}SqlRepository")
            adapter agg.name, adapter_class.new(db)
          end
        end
      end

      app.async(&@async_handler) if @async_handler
      @apps[d[:gem_name]] = app

      if @adapter_options[:event_sourced] && @db
        recorder = Persistence::EventRecorder.new(@db)
        domain_obj.aggregates.each do |agg|
          agg_class = domain_module.const_get(Hecks::Utils.sanitize_constant(agg.name))
          Persistence.bind_event_recorder(agg_class, recorder)
        end
      end

      if @ad_hoc_queries
        domain_obj.aggregates.each do |agg|
          agg_class = domain_module.const_get(Hecks::Utils.sanitize_constant(agg.name))
          Querying::AdHocQueries.bind(agg_class, app[agg.name])
        end
      end
    end

    # Attempts to activate Rails integration via the +active_hecks+ gem.
    # Silently does nothing if the gem is not installed.
    #
    # @return [void]
    def activate_rails
      begin
        require "active_hecks"
      rescue LoadError
        return
      end
      @apps.each_value do |app|
        mod = Object.const_get(domain_module_name(app.domain.name))
        ActiveHecks.activate(mod)
      end
    end
  end
end
