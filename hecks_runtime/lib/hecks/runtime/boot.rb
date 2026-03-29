require_relative "cross_domain_validator"
require_relative "event_directionality"
require_relative "queue_wiring"
require_relative "../ports/event_bus/filtered_event_bus"

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

module Hecks
  # Handles the full boot sequence for Hecks applications. Mixed into the
  # +Hecks+ module to provide +Hecks.boot(dir)+. Responsible for:
  #
  # 1. Discovering domain definition files (+hecks_domain.rb+ or +hecks_domains/+)
  # 2. Loading and compiling domain DSL into IR
  # 3. Building generated gem code and adding to +$LOAD_PATH+
  # 4. Creating Runtime instances with appropriate adapters
  # 5. Wiring persistence extensions (SQLite, Postgres, etc.)
  # 6. Firing non-persistence extensions (HTTP, audit, auth, etc.)
  # 7. Loading application service files from +services/+
  #
  # For multi-domain setups, also handles cross-domain validation,
  # event directionality filtering, and queue wiring.
  module Boot
    include HecksTemplating::NamingHelpers
    include CrossDomainValidator
    include QueueWiring

    # Load, validate, build, and wire a domain from a directory.
    # This is the primary entry point for standalone Hecks applications.
    #
    # For single-domain apps, expects a +hecks_domain.rb+ file in +dir+.
    # For multi-domain apps, expects a +hecks_domains/+ directory containing
    # one +.rb+ file per domain.
    #
    # The boot sequence:
    # 1. Auto-requires available extensions
    # 2. Detects single vs multi-domain layout
    # 3. Loads the domain DSL file(s) and compiles to IR
    # 4. Builds the generated gem(s) and adds to +$LOAD_PATH+
    # 5. Creates Runtime(s) with memory adapters by default
    # 6. Wires persistence adapter if specified via +adapter:+ or +persist_to+
    # 7. Fires non-persistence extensions
    # 8. Auto-loads +services/*.rb+ if the directory exists
    #
    # @param dir [String] directory containing +hecks_domain.rb+ or +hecks_domains/+.
    #   Defaults to +Dir.pwd+.
    # @param adapter [Symbol, Hash] persistence adapter. +:memory+ (default), +:sqlite+,
    #   +:postgres+, etc. Pass a Hash for detailed config (e.g., +{ type: :sqlite, path: "db.sqlite" }+).
    # @yield optional block evaluated on the domain module for declaring connections
    # @return [Hecks::Runtime] for single-domain apps
    # @return [Array<Hecks::Runtime>] for multi-domain apps
    # @raise [Hecks::DomainLoadError] if no domain definition file is found
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
      mod.extend(Hecks::DomainConnections) unless mod.respond_to?(:connections)

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
          require "hecks_persist/sql_boot"
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
    PERSISTENCE_EXTENSIONS = %i[sqlite postgres mysql mysql2 filesystem_store filesystem].freeze

    # Fires all non-persistence extensions that are registered in the extension registry.
    # In explicit mode (when +auto_wire+ or +extension+ was called), only fires
    # extensions that were explicitly enabled. In auto mode, fires all registered extensions.
    #
    # @param mod [Module] the domain module (e.g., +PizzaDomain+)
    # @param domain [Hecks::DomainModel::Structure::Domain] the compiled domain IR
    # @param runtime [Hecks::Runtime] the runtime instance to wire extensions into
    # @return [void]
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

    # Boots multiple domains from a +hecks_domains/+ directory. Creates a shared
    # event bus with filtered directionality so each domain only receives events
    # it should listen to. Validates that no cross-domain +reference_to+ attributes
    # exist (enforces bounded context separation).
    #
    # @param dir [String] the application root directory
    # @param domains_dir [String] path to the +hecks_domains/+ directory
    # @param adapter [Symbol, Hash] persistence adapter type
    # @yield optional configuration block
    # @return [Array<Hecks::Runtime>] one Runtime per domain
    # @raise [Hecks::DomainLoadError] if the domains directory is empty
    # @raise [Hecks::ValidationError] if cross-domain references are detected
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
        mod = Object.const_get(domain_module_name(domain.name))
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

    # Load hand-edited stub files from +lib/<gem_name>/+ that override
    # in-memory generated classes. Stubs reopen the same classes, so
    # methods defined in stubs replace the generated defaults.
    #
    # @param dir [String] the application root directory
    # @param domain [Hecks::DomainModel::Structure::Domain] the domain whose stubs to load
    # @return [void]
    def load_stubs(dir, domain)
      stubs_dir = File.join(dir, "lib", domain.gem_name)
      return unless File.directory?(stubs_dir)
      Dir[File.join(stubs_dir, "**/*.rb")].sort.each { |f| Kernel.load(f) }
    end

    # Creates a FilteredEventBus for a domain in a multi-domain setup.
    # The filter restricts which source domains' events this domain can receive,
    # based on the directionality map built from reactive policy introspection.
    #
    # @param shared_bus [Hecks::EventBus] the shared event bus across all domains
    # @param domain [Hecks::DomainModel::Structure::Domain] the domain to create a filtered bus for
    # @param all_domains [Array<Hecks::DomainModel::Structure::Domain>] all domains in the multi-domain setup
    # @return [Hecks::FilteredEventBus, Hecks::EventBus] a filtered bus, or the shared bus if no directionality exists
    def filtered_bus(shared_bus, domain, all_domains)
      @_directionality ||= EventDirectionality.build(all_domains)
      return shared_bus unless @_directionality.any?
      FilteredEventBus.new(
        inner: shared_bus,
        domain_gem_name: domain.gem_name,
        allowed_sources: @_directionality[domain.gem_name]
      )
    end

    # Normalizes the adapter parameter into a config hash.
    # If already a Hash, returns it as-is. If a Symbol, wraps it as +{ type: adapter }+.
    #
    # @param adapter [Symbol, Hash] the adapter specification
    # @return [Hash] normalized adapter config with at least a +:type+ key
    def boot_adapter_config(adapter)
      adapter.is_a?(Hash) ? adapter : { type: adapter }
    end

    # Checks whether the given adapter type is a SQL-based adapter.
    #
    # @param type [Symbol] the adapter type to check
    # @return [Boolean] true if the type is :sqlite, :postgres, :mysql, or :mysql2
    def sql_adapter_type?(type)
      [:sqlite, :postgres, :mysql, :mysql2].include?(type)
    end

    # Connects to a SQL database and sets up adapter repositories for all aggregates,
    # then swaps them into the runtime.
    #
    # @param domain [Hecks::DomainModel::Structure::Domain] the domain to wire
    # @param adapter_config [Hash] adapter configuration with +:type+ and connection details
    # @param runtime [Hecks::Runtime] the runtime whose adapters to swap
    # @return [void]
    def boot_with_sql(domain, adapter_config, runtime)
      db = SqlBoot.connect(adapter_config)
      adapters = SqlBoot.setup(domain, db)
      adapters.each { |name, repo| runtime.swap_adapter(name, repo) }
    end

  end
end
