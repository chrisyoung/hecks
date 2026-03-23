# Hecks::Configuration
#
# Wires Hecks into an application. Supports single or multiple domains with
# pluggable adapters (memory or SQL). Includes DatabaseConnection, DomainLoader,
# and SqlSetup modules for database connectivity, gem loading, and adapter generation.
#
#   Hecks.configure do
#     domain "pizzas_domain"
#     adapter :sql, database: :mysql, host: "localhost", name: "pizzas"
#   end
#
require "fileutils"
require_relative "configuration/database_connection"
require_relative "configuration/domain_loader"
require_relative "configuration/sql_setup"

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
    end

    def domain(gem_name, version: nil, path: nil)
      @domains << { gem_name: gem_name, version: version, path: path }
    end

    def adapter(type, **options)
      @adapter_type = type
      @adapter_options = options
    end

    def include_ad_hoc_queries
      @ad_hoc_queries = true
    end

    # Register an async handler for policies marked async: true
    def async(&block)
      @async_handler = block
    end

    def boot!
      @shared_event_bus = Services::EventBus.new
      @db = connect_database if @adapter_type == :sql

      @domains.each { |d| boot_domain(d) }

      # APP constant points to first app (backward compatible)
      first_app = @apps.values.first
      old = $VERBOSE; $VERBOSE = nil
      Object.const_set(:APP, first_app) if first_app
      $VERBOSE = old

      activate_rails if defined?(::Rails)
    end

    # Backward compatible: single-domain access
    def domain_obj
      @apps.values.first&.domain
    end

    def app
      @apps.values.first
    end

    private

    def boot_domain(d)
      domain_obj, domain_module = load_domain(d)
      mod = domain_obj.module_name + "Domain"
      Hecks.instance_variable_get(:@domain_objects)[mod] = domain_obj
      generate_adapters(domain_obj) if @adapter_type == :sql

      adapter_type = @adapter_type
      db = @db

      app = Services::Application.new(domain_obj, event_bus: @shared_event_bus) do
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
        recorder = Services::Persistence::EventRecorder.new(@db)
        domain_obj.aggregates.each do |agg|
          agg_class = domain_module.const_get(Hecks::Utils.sanitize_constant(agg.name))
          Services::Persistence.bind_event_recorder(agg_class, recorder)
        end
      end

      if @ad_hoc_queries
        domain_obj.aggregates.each do |agg|
          agg_class = domain_module.const_get(Hecks::Utils.sanitize_constant(agg.name))
          Services::Querying::AdHocQueries.bind(agg_class, app[agg.name])
        end
      end
    end

    def activate_rails
      require "active_hecks"
      @apps.each_value do |app|
        mod = Object.const_get(app.domain.module_name + "Domain")
        ActiveHecks.activate(mod)
      end
    end
  end
end
