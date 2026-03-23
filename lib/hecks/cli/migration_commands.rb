# Hecks::CLI::MigrationCommands
#
# Thor commands for generating and running Hecks SQL migrations.
# Included into Hecks::CLI to keep the main CLI file under 200 lines.
#
#   $ hecks generate:migrations --domain pizzas_domain
#   $ hecks db:migrate --database db/app.sqlite3
#
module Hecks
  class CLI < Thor
    desc "generate:migrations", "Generate SQL migrations from domain changes"
    option :domain, type: :string, desc: "Domain gem name (e.g. pizzas_domain)"
    map "generate:migrations" => :generate_migrations
    def generate_migrations
      domain = load_migration_domain
      return unless domain

      snapshot_path = Migrations::DomainSnapshot::DEFAULT_PATH
      old_domain = Migrations::DomainSnapshot.load(path: snapshot_path)

      changes = Migrations::DomainDiff.call(old_domain, domain)

      if changes.empty?
        say "Domain is up to date — no migrations needed.", :green
        return
      end

      # Ensure SqlStrategy is registered
      register_sql_strategy

      files = Migrations::MigrationStrategy.run_all(changes, output_dir: ".")

      if files.empty?
        say "No migration files generated.", :yellow
        return
      end

      files.each do |f|
        say "Generated #{f}", :green
        content = File.read(f)
        content.each_line { |line| say "  #{line.rstrip}", :cyan }
      end

      Migrations::DomainSnapshot.save(domain, path: snapshot_path)
      say "Saved domain snapshot to #{snapshot_path}", :green
    end

    desc "db:migrate", "Run pending Hecks SQL migrations"
    option :database, type: :string, desc: "SQLite database path"
    map "db:migrate" => :db_migrate
    def db_migrate
      connection = build_connection
      return unless connection

      runner = Migrations::MigrationRunner.new(connection: connection)
      applied = runner.run_all

      if applied.empty?
        say "No pending migrations.", :green
      else
        applied.each { |f| say "Applied #{f}", :green }
      end
    end

    private

    def load_migration_domain
      gem_name = options[:domain]

      # Try local domain.rb first (domain author workflow)
      if gem_name.nil? && File.exist?("domain.rb")
        return load_domain("domain.rb")
      end

      unless gem_name
        say "No domain.rb found and no --domain specified.", :red
        say "Usage: hecks generate:migrations --domain pizzas_domain"
        return nil
      end

      require gem_name
      gem_path = if Gem.loaded_specs[gem_name]
                   Gem.loaded_specs[gem_name].full_gem_path
                 else
                   File.join(Dir.pwd, gem_name)
                 end

      domain_file = File.join(gem_path, "domain.rb")
      unless File.exist?(domain_file)
        say "Could not find domain.rb in #{gem_path}", :red
        return nil
      end

      load_domain(domain_file)
    end

    def build_connection
      db_path = options[:database]

      if defined?(::ActiveRecord)
        return ActiveRecord::Base.connection
      end

      unless db_path
        say "No --database specified and ActiveRecord not available.", :red
        say "Usage: hecks db:migrate --database db/app.sqlite3"
        return nil
      end

      require "sqlite3"
      db = SQLite3::Database.new(db_path)
      # Wrap in a duck-type that responds to #execute
      wrapper = Object.new
      wrapper.define_singleton_method(:execute) { |sql| db.execute(sql) }
      wrapper
    end

    def register_sql_strategy
      unless Migrations::MigrationStrategy.for(:sql)
        Migrations::MigrationStrategy.register(:sql, Migrations::Strategies::SqlStrategy)
      end
    end
  end
end
