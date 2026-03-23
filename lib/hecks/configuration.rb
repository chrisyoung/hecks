# Hecks::Configuration
#
# Config block for wiring Hecks into an application. Handles loading the
# domain gem, choosing adapters, database connection, and booting.
#
#   Hecks.configure do
#     domain "pizzas_domain", version: "2026.03.22.1"
#     adapter :sql, database: :mysql, host: "localhost",
#       user: "root", password: "secret", name: "pizzas"
#     include_ad_hoc_queries
#   end
#
# Database options:
#   database: :sqlite (default), :mysql, :postgres
#   url: "mysql2://user:pass@host/db" (alternative to individual options)
#   host:, user:, password:, name: (individual connection params)
#
require "fileutils"

module Hecks
  class Configuration
    attr_reader :domain_obj, :app

    def initialize
      @gem_name = nil
      @adapter_type = :memory
      @adapter_options = {}
      @domain_obj = nil
      @app = nil
      @ad_hoc_queries = false
    end

    def domain(gem_name, version: nil)
      @gem_name = gem_name
      @gem_version = version
    end

    def adapter(type, **options)
      @adapter_type = type
      @adapter_options = options
    end

    def include_ad_hoc_queries
      @ad_hoc_queries = true
    end

    def boot!
      load_domain
      generate_adapters if @adapter_type == :sql
      create_application
      bind_event_recorder if @adapter_options[:event_sourced]
      bind_ad_hoc_queries if @ad_hoc_queries
      activate_rails if defined?(::Rails)
    end

    private

    def load_domain
      gem @gem_name, @gem_version if @gem_version
      require @gem_name

      gem_path = if Gem.loaded_specs[@gem_name]
                   Gem.loaded_specs[@gem_name].full_gem_path
                 elsif defined?(::Rails)
                   ::Rails.root.join(@gem_name).to_s
                 else
                   File.join(Dir.pwd, @gem_name)
                 end

      domain_file = File.join(gem_path, "domain.rb")
      @domain_obj = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)
      @domain_module = Object.const_get(@domain_obj.module_name + "Domain")
    end

    def generate_adapters
      @domain_obj.aggregates.each do |agg|
        gen = Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: @domain_obj.module_name + "Domain")
        eval(gen.generate, TOPLEVEL_BINDING, "(hecks:sql:#{agg.name})")
      end
    end

    def create_application
      adapter_type = @adapter_type
      domain_module = @domain_module
      domain_obj = @domain_obj
      @db = connect_database if adapter_type == :sql
      db = @db

      @app = Services::Application.new(@domain_obj) do
        if adapter_type == :sql
          domain_obj.aggregates.each do |agg|
            adapter_class = domain_module::Adapters.const_get("#{agg.name}SqlRepository")
            adapter agg.name, adapter_class.new(db)
          end
        end
      end

      old = $VERBOSE; $VERBOSE = nil
      Object.const_set(:APP, @app)
      $VERBOSE = old
    end

    def connect_database
      require "sequel"

      if @adapter_options[:url]
        Sequel.connect(@adapter_options[:url])
      elsif @adapter_options[:database]
        connect_by_type(@adapter_options)
      elsif defined?(::Rails)
        connect_from_rails
      else
        Sequel.sqlite
      end
    end

    def connect_by_type(opts)
      case opts[:database]
      when :mysql
        Sequel.connect(
          adapter: :mysql2,
          host: opts[:host] || "localhost",
          user: opts[:user] || "root",
          password: opts[:password],
          database: opts[:name]
        )
      when :postgres
        Sequel.connect(
          adapter: :postgres,
          host: opts[:host] || "localhost",
          user: opts[:user],
          password: opts[:password],
          database: opts[:name]
        )
      when :sqlite
        Sequel.sqlite(opts[:name])
      else
        raise "Unknown database type: #{opts[:database]}. Use :sqlite, :mysql, or :postgres."
      end
    end

    def connect_from_rails
      db_config = ActiveRecord::Base.connection_db_config
      url = db_config.try(:url) || db_config.configuration_hash[:url]
      url ? Sequel.connect(url) : Sequel.sqlite
    end

    def bind_event_recorder
      recorder = Services::Persistence::EventRecorder.new(@db)
      @domain_obj.aggregates.each do |agg|
        agg_class = @domain_module.const_get(agg.name)
        Services::Persistence.bind_event_recorder(agg_class, recorder)
      end
    end

    def bind_ad_hoc_queries
      @domain_obj.aggregates.each do |agg|
        agg_class = @domain_module.const_get(agg.name)
        Services::Querying::AdHocQueries.bind(agg_class, @app[agg.name])
      end
    end

    def activate_rails
      require "active_hecks"
      ActiveHecks.activate(@domain_module)
    end
  end
end
