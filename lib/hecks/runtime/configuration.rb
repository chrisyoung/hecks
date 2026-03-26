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
require "fileutils"
require_relative "../../hecks_persist/database_connection"
require_relative "configuration/domain_loader"
require_relative "../../hecks_persist/sql_setup"

module Hecks
  class Configuration
    include DatabaseConnection
    include DomainLoader
    include SqlSetup

    attr_reader :apps

    def initialize
      @domains = []
      @adapter_type = :memory
      @adapter_options = {}
      @apps = {}
      @ad_hoc_queries = false
      @extensions = {}
      @extensions_explicit = false
    end

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

    # DSL helper for domain block — collects listens_to / sends_to declarations.
    class DomainConfigBuilder
      attr_reader :listens, :sends

      def initialize
        @listens = []
        @sends = []
      end

      def listens_to(source)
        @listens << source
      end

      def sends_to(target)
        @sends << target
      end
    end

    def adapter(type, **options)
      @adapter_type = type
      @adapter_options = options
    end

    def include_ad_hoc_queries
      @ad_hoc_queries = true
    end

    # Declaratively auto-wire all detected extensions.
    # Detects what's installed, enables everything by default.
    #
    #   auto_wire                        # enable all detected
    #   auto_wire except: [:pii]         # all except PII
    #   auto_wire only: [:http, :audit]  # only these two
    #
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

    # Explicitly enable an extension with options.
    # Overrides auto_wire defaults for this extension.
    #
    #   extension :http, port: 9292
    #   extension :sockets, port: 9293
    #
    def extension(name, **options)
      @extensions_explicit = true
      @extensions[name.to_sym] = options
    end

    def extensions_explicit?
      @extensions_explicit
    end

    def extensions
      @extensions
    end

    def async(&block)
      @async_handler = block
    end

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

    def domain_obj
      @apps.values.first&.domain
    end

    def app
      @apps.values.first
    end

    private

    def build_declarations
      decl = {}
      @domains.each do |d|
        next unless d[:listens_to]&.any?
        decl[d[:gem_name]] = d[:listens_to].map(&:to_s)
      end
      decl
    end

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

    def boot_domain(d)
      domain_obj, domain_module = load_domain(d)
      mod = domain_obj.module_name + "Domain"
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

    def activate_rails
      begin
        require "active_hecks"
      rescue LoadError
        return
      end
      @apps.each_value do |app|
        mod = Object.const_get(app.domain.module_name + "Domain")
        ActiveHecks.activate(mod)
      end
    end
  end
end
