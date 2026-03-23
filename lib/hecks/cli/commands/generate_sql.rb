# Hecks::CLI generate commands
#
module Hecks
  class CLI < Thor
    desc "generate:sql", "Generate SQL migration and adapter from domain.rb"
    map "generate:sql" => :generate_sql
    def generate_sql
      domain_file = find_domain_file
      unless domain_file
        say "No domain.rb found in current directory", :red
        return
      end

      domain = load_domain(domain_file)
      mod = domain.module_name + "Domain"
      gem_name = domain.gem_name

      validator = Validator.new(domain)
      unless validator.valid?
        say "Domain validation failed:", :red
        validator.errors.each { |e| say "  - #{e}", :red }
        return
      end

      migration_gen = Generators::SQL::SqlMigrationGenerator.new(domain)
      migration = migration_gen.generate

      FileUtils.mkdir_p("db")
      File.write("db/schema.sql", migration)
      say "Generated db/schema.sql", :green

      gem_dir = gem_name
      if Dir.exist?(gem_dir)
        domain.aggregates.each do |agg|
          adapter_gen = Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: mod)
          path = File.join(gem_dir, "lib/#{gem_name}/adapters/#{Hecks::Utils.underscore(agg.name)}_sql_repository.rb")
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, adapter_gen.generate)
          say "Generated #{path}", :green
        end
      else
        say "Domain gem not found at #{gem_dir}/. Run 'hecks build' first.", :yellow
      end
    end
  end
end
