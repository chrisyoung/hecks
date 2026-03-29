
# Hecks::Boot
#
# Loads a domain from a directory, validates, builds, and wires a Runtime.
# Single domain: expects hecks_domain.rb. Multi-domain: expects hecks_domains/.
#
#   app = Hecks.boot(__dir__)
#   app = Hecks.boot(__dir__, adapter: :sqlite)
#
module Hecks
  module Boot
    include HecksTemplating::NamingHelpers

    # @param dir [String] directory containing hecks_domain.rb or hecks_domains/
    # @param adapter [Symbol, Hash] persistence adapter (:memory, :sqlite, etc.)
    # @yield optional block on domain module for declaring connections
    # @return [Hecks::Runtime, Array<Hecks::Runtime>]
    def boot(dir = Dir.pwd, adapter: :memory, &block)
      require_relative "load_extensions"
      LoadExtensions.require_auto

      multi_dir = find_domains_dir(dir)
      return boot_multi(dir, multi_dir, adapter: adapter, &block) if multi_dir

      domain, mod = load_single_domain(dir)
      mod.instance_eval(&block) if block
      runtime = Runtime.new(domain)
      wire_persistence(mod, domain, runtime, adapter)
      fire_extensions(mod, domain, runtime)
      autoload_services(dir)
      runtime
    end

    private

    def persistence_extension?(name)
      Hecks.adapter?(name)
    end

    def find_domains_dir(dir)
      candidates = [File.join(dir, "hecks_domains"), File.join(dir, "domains")]
      candidates.find { |d| File.directory?(d) }
    end

    def load_single_domain(dir)
      domain_file = File.join(dir, "hecks_domain.rb")
      raise Hecks::DomainLoadError, "No hecks_domain.rb or domains/ found in #{dir}" unless File.exist?(domain_file)

      Kernel.load(domain_file)
      domain = Hecks.last_domain
      domain.source_path = domain_file

      mod = load_domain(domain)
      load_stubs(dir, domain)
      mod.extend(Hecks::DomainConnections) unless mod.respond_to?(:connections)
      [domain, mod]
    end

    def wire_persistence(mod, domain, runtime, adapter)
      persist = mod.connections[:persist] || {}
      boot_cfg = adapter == :memory ? nil : normalize_adapter(adapter)
      effective = persist[:default] || persist.values.first || boot_cfg
      return unless effective

      hook = Hecks.extension_registry[effective[:type]]
      if hook
        hook.call(mod, domain, runtime)
      elsif sql_adapter_type?(effective[:type])
        require "hecks_persist/sql_boot"
        boot_with_sql(domain, effective, runtime)
      end
    end

    def fire_extensions(mod, domain, runtime)
      config = Hecks.configuration
      explicit = config&.extensions_explicit?

      Hecks.extension_registry.each do |name, hook|
        next if persistence_extension?(name)
        next unless hook.respond_to?(:call)
        next if explicit && !config.extensions.key?(name)
        hook.call(mod, domain, runtime)
      end
    end

    def autoload_services(dir)
      services_dir = File.join(dir, "services")
      return unless File.directory?(services_dir)
      Dir[File.join(services_dir, "*.rb")].sort.each { |f| require f }
    end

    def boot_multi(dir, domains_dir, adapter: :memory, &block)
      domain_files = Dir[File.join(domains_dir, "*.rb")].sort
      raise Hecks::DomainLoadError, "No .rb files in #{domains_dir}" if domain_files.empty?

      domains = domain_files.map { |path| eval(File.read(path), nil, path, 1) }
      Hecks::MultiDomain::Validator.validate_no_cross_domain_references(domains)
      domains.each { |d| load_domain(d); load_stubs(dir, d) }

      shared_bus = EventBus.new
      @shared_event_bus = shared_bus
      directionality = Hecks::MultiDomain::Directionality.build(domains)
      runtimes = domains.map do |d|
        bus = directionality.any? ? FilteredEventBus.new(inner: shared_bus, domain_gem_name: d.gem_name, allowed_sources: directionality[d.gem_name]) : shared_bus
        Runtime.new(d, event_bus: bus)
      end
      Hecks::MultiDomain::QueueWiring.wire(domains, runtimes)

      domains.each_with_index do |domain, i|
        mod = Object.const_get(domain_module_name(domain.name))
        fire_extensions(mod, domain, runtimes[i])
      end

      autoload_services(dir)
      runtimes
    end

    def load_stubs(dir, domain)
      stubs_dir = File.join(dir, "lib", domain.gem_name)
      return unless File.directory?(stubs_dir)
      Dir[File.join(stubs_dir, "**/*.rb")].sort.each { |f| Kernel.load(f) }
    end

    def filtered_bus(shared_bus, domain, all_domains)
      @_directionality ||= EventDirectionality.build(all_domains)
      return shared_bus unless @_directionality.any?
      FilteredEventBus.new(
        inner: shared_bus,
        domain_gem_name: domain.gem_name,
        allowed_sources: @_directionality[domain.gem_name]
      )
    end

    def normalize_adapter(adapter)
      adapter.respond_to?(:to_hash) ? adapter : { type: adapter }
    end

    def sql_adapter_type?(type)
      %i[sqlite postgres mysql mysql2].include?(type)
    end

    def boot_with_sql(domain, adapter_config, runtime)
      db = SqlBoot.connect(adapter_config)
      adapters = SqlBoot.setup(domain, db)
      adapters.each { |name, repo| runtime.swap_adapter(name, repo) }
    end
  end
end
