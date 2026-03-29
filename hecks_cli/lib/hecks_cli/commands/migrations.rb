
# Hecks::CLI::Domain migration commands
#
# Three migration-related subcommands:
#   generate:migrations -- diffs the domain against a saved snapshot and generates SQL migration files
#   generate:sql        -- generates db/schema.sql and per-aggregate SQL adapter classes
#   db:migrate          -- runs pending SQL migrations against SQLite or ActiveRecord
#
#   hecks domain generate:migrations [--domain NAME]
#   hecks domain generate:sql [--domain NAME]
#   hecks domain db:migrate [--database PATH]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      include Hecks::Templating::Names
      desc "generate:migrations", "Generate SQL migrations from domain changes"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      map "generate:migrations" => :generate_migrations
      # Generates SQL migration files by diffing the current domain against
      # its last saved snapshot.
      #
      # Loads the previous snapshot from db/hecks_domain_snapshot.json, computes
      # a diff, and generates ALTER TABLE / CREATE TABLE SQL statements. Saves
      # the current domain as the new snapshot after generation.
      #
      # @return [void]
      def generate_migrations
        domain = resolve_domain_option
        return unless domain

        snapshot_path = Migrations::DomainSnapshot::DEFAULT_PATH
        old_domain = Migrations::DomainSnapshot.load(path: snapshot_path)
        changes = Migrations::DomainDiff.call(old_domain, domain)

        if changes.empty?
          say "Domain is up to date — no migrations needed.", :green
          return
        end

        register_sql_strategy
        files = Migrations::MigrationStrategy.run_all(changes, output_dir: ".")

        if files.empty?
          say "No migration files generated.", :yellow
          return
        end

        files.each do |f|
          say "Generated #{f}", :green
          File.read(f).each_line { |line| say "  #{line.rstrip}", :cyan }
        end

        Migrations::DomainSnapshot.save(domain, path: snapshot_path)
        say "Saved domain snapshot to #{snapshot_path}", :green
      end

      desc "generate:sql", "Generate SQL schema and adapters"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      map "generate:sql" => :generate_sql
      # Generates db/schema.sql and per-aggregate SQL adapter classes.
      #
      # Produces a full CREATE TABLE schema and Sequel-based repository
      # adapter classes for each aggregate. Adapter files are written into
      # the domain gem's lib directory.
      #
      # @return [void]
      def generate_sql
        domain = resolve_domain_option
        return unless domain
        mod = domain_module_name(domain.name)
        gem_name = domain.gem_name

        migration_gen = Generators::SQL::SqlMigrationGenerator.new(domain)
        FileUtils.mkdir_p("db")
        File.write("db/schema.sql", migration_gen.generate)
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
          say "Domain gem not found at #{gem_dir}/. Run 'hecks domain build' first.", :yellow
        end
      end

      desc "db:migrate", "Run pending Hecks SQL migrations"
      option :database, type: :string, desc: "SQLite database path"
      map "db:migrate" => :db_migrate
      # Runs pending SQL migrations from db/hecks_migrate/.
      #
      # Uses ActiveRecord's connection if available, otherwise requires
      # a --database path for SQLite. Applies each unapplied migration
      # in timestamp order.
      #
      # @return [void]
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

      # Builds a database connection for running migrations.
      #
      # Prefers ActiveRecord if available, otherwise requires a --database
      # path for SQLite. Returns a wrapper object with an #execute method.
      #
      # @return [Object, nil] a connection object with #execute, or nil
      def build_connection
        db_path = options[:database]
        if defined?(::ActiveRecord)
          return ActiveRecord::Base.connection
        end
        unless db_path
          say "No --database specified and ActiveRecord not available.", :red
          return nil
        end
        require "sqlite3"
        db = SQLite3::Database.new(db_path)
        wrapper = Object.new
        wrapper.define_singleton_method(:execute) { |sql| db.execute(sql) }
        wrapper
      end

      # Registers the SQL migration strategy if not already registered.
      #
      # @return [void]
      def register_sql_strategy
        unless Migrations::MigrationStrategy.for(:sql)
          Migrations::MigrationStrategy.register(:sql, Migrations::Strategies::SqlStrategy)
        end
      end
    end
  end
end
