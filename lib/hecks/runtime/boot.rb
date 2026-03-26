# Hecks::Boot
#
# Convenience method that loads a domain from a directory, validates it,
# builds the gem, adds it to $LOAD_PATH, and returns a wired Runtime.
# Defaults to memory adapters. Extension gems (hecks_sqlite, hecks_serve,
# etc.) auto-wire via the extension registry when present.
#
# Single domain: expects hecks_domain.rb in the directory.
# Multi-domain: if hecks_domains/ exists, loads all .rb files, builds each
# gem, creates a shared EventBus with filtered directionality, and returns
# an array of Runtimes.
#
#   app = Hecks.boot(__dir__)
#   app = Hecks.boot(__dir__, adapter: :sqlite)
#   apps = Hecks.boot(__dir__)  # returns array if hecks_domains/ exists
#
require_relative "cross_domain_validator"
require_relative "event_directionality"
require_relative "queue_wiring"
require_relative "../ports/event_bus/filtered_event_bus"

module Hecks
  module Boot
    include CrossDomainValidator
    include QueueWiring

    # Load, validate, build, and wire a domain from a directory.
    #
    # @param dir [String] directory containing hecks_domain.rb
    # @param adapter [Symbol, Hash] :memory (default), :sqlite, :postgres, etc.
    # @param block [Proc] optional block evaluated on the domain module for connections
    # @return [Hecks::Runtime]
    # Non-persistence extension gems — auto-required if available.
    # Persistence (sqlite/postgres/mysql) is explicit via adapter: keyword.
    def boot(dir = Dir.pwd, adapter: :memory, &block)
      require_relative "load_extensions"
      LoadExtensions.require_auto

      domains_dir = File.join(dir, "hecks_domains")
      unless File.directory?(domains_dir)
        # Fallback to legacy domains/ directory
        legacy = File.join(dir, "domains")
        domains_dir = legacy if File.directory?(legacy)
      end
      if File.directory?(domains_dir)
        return boot_multi(dir, domains_dir, adapter: adapter, &block)
      end

      domain_file = File.join(dir, "hecks_domain.rb")
      unless File.exist?(domain_file)
        raise Hecks::DomainLoadError, "No hecks_domain.rb or domains/ found in #{dir}"
      end

      Kernel.load(domain_file)
      domain = Hecks.last_domain
      domain.source_path = domain_file

      mod = load_domain(domain)
      mod_name = mod.name
      load_stubs(dir, domain)
      mod.extend(Hecks::DomainConnections) unless mod.respond_to?(:persist_to)

      # Evaluate the boot block on the domain module before creating Runtime
      mod.instance_eval(&block) if block

      runtime = Runtime.new(domain)

      # Wire persistence: explicit adapter keyword or declared via persist_to
      persist = mod.connections[:persist] || {}
      boot_adapter = adapter == :memory ? nil : boot_adapter_config(adapter)
      effective = persist[:default] || persist.values.first || boot_adapter
      if effective
        hook = Hecks.extension_registry[effective[:type]]
        if hook
          hook.call(mod, domain, runtime)
        elsif sql_adapter_type?(effective[:type])
          require_relative "../../hecks_persist/sql_boot"
          boot_with_sql(domain, effective, runtime)
        end
      end

      # Fire non-persistence extensions (sockets, audit, auth, etc.)
      fire_extensions(mod, domain, runtime)

      # Auto-load application services
      services_dir = File.join(dir, "services")
      if File.directory?(services_dir)
        Dir[File.join(services_dir, "*.rb")].sort.each { |f| require f }
      end

      runtime
    end

    private

    # Persistence extensions are keyed by adapter type (:sqlite, :postgres, etc.)
    PERSISTENCE_EXTENSIONS = %i[sqlite postgres mysql mysql2].freeze

    def fire_extensions(mod, domain, runtime)
      config = Hecks.configuration
      explicit = config&.extensions_explicit?

      Hecks.extension_registry.each do |name, hook|
        next if PERSISTENCE_EXTENSIONS.include?(name)
        next unless hook.respond_to?(:call)
        next if explicit && !config.extensions.key?(name)
        hook.call(mod, domain, runtime)
      end
    end

    def boot_multi(dir, domains_dir, adapter: :memory, &block)
      domain_files = Dir[File.join(domains_dir, "*.rb")].sort
      raise Hecks::DomainLoadError, "No .rb files in #{domains_dir}" if domain_files.empty?

      domains = domain_files.map do |path|
        eval(File.read(path), nil, path, 1)
      end

      # Cross-domain validation: reject shared kernel patterns
      validate_no_cross_domain_references(domains)

      domains.each do |domain|
        load_domain(domain)
        load_stubs(dir, domain)
      end

      shared_bus = EventBus.new
      @shared_event_bus = shared_bus
      runtimes = domains.map do |d|
        Runtime.new(d, event_bus: filtered_bus(shared_bus, d, domains))
      end

      wire_queue(domains, runtimes)

      # Fire registered extensions on each domain
      domains.each_with_index do |domain, i|
        mod = Object.const_get(domain.module_name + "Domain")
        Hecks.extension_registry.each do |_name, hook|
          hook.call(mod, domain, runtimes[i])
        end
      end

      # Auto-load application services
      services_dir = File.join(dir, "services")
      if File.directory?(services_dir)
        Dir[File.join(services_dir, "*.rb")].sort.each { |f| require f }
      end

      runtimes
    end

    # Load hand-edited stub files from lib/<gem_name>/ that override
    # in-memory generated classes. Stubs reopen the same classes, so
    # methods defined in stubs replace the generated defaults.
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

    def boot_adapter_config(adapter)
      adapter.is_a?(Hash) ? adapter : { type: adapter }
    end

    def sql_adapter_type?(type)
      [:sqlite, :postgres, :mysql, :mysql2].include?(type)
    end

    def boot_with_sql(domain, adapter_config, runtime)
      db = SqlBoot.connect(adapter_config)
      adapters = SqlBoot.setup(domain, db)
      adapters.each { |name, repo| runtime.swap_adapter(name, repo) }
    end

  end
end
