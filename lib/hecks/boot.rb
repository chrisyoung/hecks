# Hecks::Boot
#
# Convenience method that loads a domain from a directory, validates it,
# builds the gem, adds it to $LOAD_PATH, and returns a wired Runtime.
# Supports memory (default) and SQL adapters. SQL adapters automatically
# generate repository classes, create tables, and wire everything up.
#
# Part of the top-level Hecks API. Mixed into the Hecks module via extend.
#
#   app = Hecks.boot(__dir__)
#   app = Hecks.boot(__dir__, adapter: :sqlite)
#   app = Hecks.boot(__dir__, adapter: { type: :sqlite, database: "app.db" })
#
require_relative "boot/sql_boot"

module Hecks
  module Boot
    # Load, validate, build, and wire a domain from a directory.
    #
    # @param dir [String] directory containing hecks_domain.rb
    # @param adapter [Symbol, Hash] :memory (default), :sqlite, or { type: :sqlite, database: "path" }
    # @return [Hecks::Services::Runtime]
    def boot(dir, adapter: :memory)
      domain_file = File.join(dir, "hecks_domain.rb")
      unless File.exist?(domain_file)
        raise Hecks::DomainLoadError, "No hecks_domain.rb found in #{dir}"
      end

      domain = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file, 1)

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

      if sql_adapter?(adapter)
        boot_with_sql(domain, adapter)
      else
        Services::Runtime.new(domain)
      end
    end

    private

    def sql_adapter?(adapter)
      return false if adapter == :memory
      type = adapter.is_a?(Hash) ? adapter[:type] : adapter
      [:sqlite, :postgres, :mysql, :mysql2].include?(type)
    end

    def boot_with_sql(domain, adapter)
      db = SqlBoot.connect(adapter)
      adapters = SqlBoot.setup(domain, db)
      Services::Runtime.new(domain) do
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
