# Hecks::Configuration
#
# Simple config block for wiring Hecks into an application. Handles
# loading the domain gem, choosing adapters, and booting the Application.
#
#   Hecks.configure do
#     domain "pizzas_domain"
#     adapter :sql
#   end
#
# Adapter options:
#   :memory  — default, in-memory hash storage
#   :sql     — generates SQL adapter classes from the domain, uses ActiveRecord connection
#
require "fileutils"

module Hecks
  class Configuration
    attr_reader :domain_obj, :app

    def initialize
      @gem_name = nil
      @adapter_type = :memory
      @domain_obj = nil
      @app = nil
    end

    def domain(gem_name)
      @gem_name = gem_name
    end

    def adapter(type)
      @adapter_type = type
    end

    def boot!
      load_domain
      generate_adapters if @adapter_type == :sql
      create_application
      activate_rails if defined?(::Rails)
    end

    private

    def load_domain
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
        gen = Generators::SqlAdapterGenerator.new(agg, domain_module: @domain_obj.module_name + "Domain")
        eval(gen.generate, TOPLEVEL_BINDING, "(hecks:sql:#{agg.name})")
      end
    end

    def create_application
      adapter_type = @adapter_type
      domain_module = @domain_module
      domain_obj = @domain_obj

      @app = Services::Application.new(@domain_obj) do
        if adapter_type == :sql
          db = Object.new
          db.define_singleton_method(:execute) do |sql, binds = []|
            conn = ActiveRecord::Base.connection
            if binds.empty?
              conn.exec_query(sql).to_a
            else
              # Sanitize binds into the SQL (ActiveRecord handles escaping)
              sanitized = sql.dup
              binds.each do |val|
                sanitized.sub!("?", conn.quote(val))
              end
              conn.exec_query(sanitized).to_a
            end
          end

          domain_obj.aggregates.each do |agg|
            adapter_class = domain_module::Adapters.const_get("#{agg.name}SqlRepository")
            adapter agg.name, adapter_class.new(db)
          end
        end
      end

      # Make APP available globally (silently replace if already defined)
      old = $VERBOSE; $VERBOSE = nil
      Object.const_set(:APP, @app)
      $VERBOSE = old
    end

    def activate_rails
      require "hecks/rails"
      Hecks::Rails.activate(@domain_module)
    end
  end
end
