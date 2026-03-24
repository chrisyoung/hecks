# Hecks::Boot
#
# Convenience method that loads a domain from a directory, validates it,
# builds the gem, adds it to $LOAD_PATH, and returns a wired Runtime.
# Supports memory (default) and SQL adapters. SQL adapters automatically
# generate repository classes, create tables, and wire everything up.
# Accepts an optional block for declaring domain connections (persist_to,
# listens_to, sends_to) before the Runtime is created.
#
# Part of the top-level Hecks API. Mixed into the Hecks module via extend.
#
#   app = Hecks.boot(__dir__)
#   app = Hecks.boot(__dir__, adapter: :sqlite)
#   app = Hecks.boot(__dir__) do
#     persist_to :sqlite
#     sends_to :notifications, MyAdapter.new
#   end
#
require_relative "../hecks_persist/sql_boot"

module Hecks
  module Boot
    # Load, validate, build, and wire a domain from a directory.
    #
    # @param dir [String] directory containing hecks_domain.rb
    # @param adapter [Symbol, Hash] :memory (default), :sqlite, or { type: :sqlite, database: "path" }
    # @param block [Proc] optional block evaluated on the domain module for connections
    # @return [Hecks::Runtime]
    def boot(dir, adapter: :memory, &block)
      domain_file = File.join(dir, "hecks_domain.rb")
      unless File.exist?(domain_file)
        raise Hecks::DomainLoadError, "No hecks_domain.rb found in #{dir}"
      end

      Kernel.load(domain_file)
      domain = Hecks.last_domain

      valid, errors = validate(domain)
      unless valid
        errors.each { |e| $stderr.puts "  - #{e}" }
        raise Hecks::ValidationError, "Domain validation failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
      end

      output = build(domain, version: Time.now.strftime("%Y.%m.%d.1"), output_dir: dir)

      lib_path = File.join(output, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      require domain.gem_name
      load_generated_files(output, domain)

      mod_name = domain.module_name + "Domain"
      mod = Object.const_get(mod_name)
      mod.extend(Hecks::DomainConnections) unless mod.respond_to?(:persist_to)

      # adapter: keyword is shorthand for persist_to
      unless adapter == :memory
        if adapter.is_a?(Hash)
          type = adapter[:type]
          opts = adapter.reject { |k, _| k == :type }
          mod.persist_to(type, **opts)
        else
          mod.persist_to(adapter)
        end
      end

      # Evaluate the boot block on the domain module before creating Runtime
      mod.instance_eval(&block) if block

      effective_adapter = mod.connections[:persist]
      if effective_adapter && sql_adapter_type?(effective_adapter[:type])
        boot_with_sql(domain, effective_adapter)
      else
        Runtime.new(domain)
      end
    end

    private

    def sql_adapter?(adapter)
      return false if adapter == :memory
      type = adapter.is_a?(Hash) ? adapter[:type] : adapter
      sql_adapter_type?(type)
    end

    def sql_adapter_type?(type)
      [:sqlite, :postgres, :mysql, :mysql2].include?(type)
    end

    def boot_with_sql(domain, adapter_config)
      db = SqlBoot.connect(adapter_config)
      adapters = SqlBoot.setup(domain, db)
      Runtime.new(domain) do
        adapters.each { |name, repo| adapter(name, repo) }
      end
    end

    # Eagerly load generated .rb files (subscribers, specifications, etc.)
    # that aren't covered by the gem's autoload declarations.
    # Skips commands and queries (resolved via const_missing at runtime).
    def load_generated_files(output, domain)
      gem_dir = File.join(output, "lib", domain.gem_name)
      Dir[File.join(gem_dir, "**/*.rb")].sort.each do |f|
        next if f.include?("/commands/") || f.include?("/queries/")
        Kernel.load f
      end
    end
  end
end
