# Hecks::Configuration
#
# Wires Hecks into an application. Supports single or multiple domains.
#
#   domain "pizzas_domain", version: "2026.03.22.1"  # from gem
#   domain "pizzas_domain", path: "domain/"           # local, builds on boot
#   domain "pizzas_domain"                             # multiple domains share event bus
#   domain "billing_domain"
#   adapter :sql, database: :mysql, host: "localhost", name: "pizzas"
#
require "fileutils"

module Hecks
  class Configuration
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
      generate_adapters(domain_obj) if @adapter_type == :sql

      adapter_type = @adapter_type
      db = @db

      app = Services::Application.new(domain_obj, event_bus: @shared_event_bus) do
        if adapter_type == :sql
          domain_obj.aggregates.each do |agg|
            adapter_class = domain_module::Adapters.const_get("#{agg.name}SqlRepository")
            adapter agg.name, adapter_class.new(db)
          end
        end
      end

      @apps[d[:gem_name]] = app

      if @adapter_options[:event_sourced] && @db
        recorder = Services::Persistence::EventRecorder.new(@db)
        domain_obj.aggregates.each do |agg|
          agg_class = domain_module.const_get(agg.name)
          Services::Persistence.bind_event_recorder(agg_class, recorder)
        end
      end

      if @ad_hoc_queries
        domain_obj.aggregates.each do |agg|
          agg_class = domain_module.const_get(agg.name)
          Services::Querying::AdHocQueries.bind(agg_class, app[agg.name])
        end
      end
    end

    def load_domain(d)
      if d[:path]
        load_from_path(d)
      else
        load_from_gem(d)
      end
    end

    def load_from_path(d)
      base = if defined?(::Rails)
               ::Rails.root.join(d[:path]).to_s
             else
               File.expand_path(d[:path])
             end

      domain_file = File.join(base, "domain.rb")
      domain_obj = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)

      gem_path = Hecks.build(domain_obj, output_dir: base)
      lib_path = File.join(gem_path, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      require d[:gem_name]
      Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
      domain_module = Object.const_get(domain_obj.module_name + "Domain")
      [domain_obj, domain_module]
    end

    def load_from_gem(d)
      gem d[:gem_name], d[:version] if d[:version]
      require d[:gem_name]

      gem_path = if Gem.loaded_specs[d[:gem_name]]
                   Gem.loaded_specs[d[:gem_name]].full_gem_path
                 elsif defined?(::Rails)
                   ::Rails.root.join(d[:gem_name]).to_s
                 else
                   File.join(Dir.pwd, d[:gem_name])
                 end

      domain_file = File.join(gem_path, "domain.rb")
      domain_obj = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file)
      domain_module = Object.const_get(domain_obj.module_name + "Domain")
      [domain_obj, domain_module]
    end

    def generate_adapters(domain_obj)
      domain_obj.aggregates.each do |agg|
        gen = Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: domain_obj.module_name + "Domain")
        eval(gen.generate, TOPLEVEL_BINDING, "(hecks:sql:#{agg.name})")
      end
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
        Sequel.connect(adapter: :mysql2, host: opts[:host] || "localhost",
          user: opts[:user] || "root", password: opts[:password], database: opts[:name])
      when :postgres
        Sequel.connect(adapter: :postgres, host: opts[:host] || "localhost",
          user: opts[:user], password: opts[:password], database: opts[:name])
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

    def activate_rails
      require "active_hecks"
      @apps.each_value do |app|
        mod = Object.const_get(app.domain.module_name + "Domain")
        ActiveHecks.activate(mod)
      end
    end
  end
end
