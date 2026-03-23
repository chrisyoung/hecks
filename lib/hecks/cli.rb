# Hecks::CLI
#
# Thor-based command-line interface for creating, validating, and building
# Hecks domain projects. This is the user-facing entry point invoked by
# the `hecks` executable.
#
# Part of the outer shell of the Hecks architecture -- orchestrates the
# DSL, Validator, Versioner, and Generators to drive the full workflow.
#
#   $ hecks init
#   $ hecks validate
#   $ hecks build
#   $ hecks console
#   $ hecks generate:sql
#   $ hecks generate:migrations
#   $ hecks db:migrate
#
require "thor"
require "fileutils"

module Hecks
  class CLI < Thor
    desc "init [NAME]", "Initialize a Hecks domain in the current directory"
    def init(name = nil)
      if File.exist?("domain.rb")
        say "domain.rb already exists in this directory", :yellow
        return
      end

      name ||= File.basename(Dir.pwd).split(/[_\-\s]/).map(&:capitalize).join

      File.write("domain.rb", domain_template(name))
      File.write("verbs.txt", "# Add custom action verbs here (one per line)\n# WordNet handles most English verbs automatically\n")
      File.write(".hecks_version", "")

      say "Initialized Hecks domain: #{name}", :green
      say "  domain.rb   — define your domain here"
      say "  verbs.txt   — add custom action verbs (optional)"
      say ""
      say "Next steps:"
      say "  hecks console   # edit interactively"
      say "  hecks build     # generate the domain gem"
    end

    desc "build", "Generate the domain gem from domain.rb"
    def build
      domain_file = find_domain_file

      unless domain_file
        say "No domain.rb found in current directory", :red
        return
      end

      domain = load_domain(domain_file)

      validator = Validator.new(domain)
      unless validator.valid?
        say "Domain validation failed:", :red
        validator.errors.each { |e| say "  - #{e}", :red }
        return
      end

      versioner = Versioner.new(".")
      version = versioner.next

      generator = Generators::Infrastructure::DomainGemGenerator.new(domain, version: version)
      output = generator.generate

      say "Built #{domain.gem_name} v#{version}", :green
      say "  Output: #{output}/"
    end

    desc "validate", "Validate the domain definition"
    def validate
      domain_file = find_domain_file

      unless domain_file
        say "No domain.rb found in current directory", :red
        return
      end

      domain = load_domain(domain_file)
      validator = Validator.new(domain)

      if validator.valid?
        say "Domain is valid", :green
        say ""
        say "Aggregates:"
        domain.aggregates.each do |agg|
          say "  #{agg.name}"
          say "    Attributes:     #{agg.attributes.map(&:name).join(', ')}"
          say "    Value Objects:  #{agg.value_objects.map(&:name).join(', ')}" unless agg.value_objects.empty?
          say "    Commands:       #{agg.commands.map(&:name).join(', ')}" unless agg.commands.empty?
          say "    Events:         #{agg.events.map(&:name).join(', ')}" unless agg.events.empty?
          say "    Policies:       #{agg.policies.map(&:name).join(', ')}" unless agg.policies.empty?
        end
      else
        say "Domain validation failed:", :red
        validator.errors.each { |e| say "  - #{e}", :red }
      end
    end

    desc "console [NAME]", "Start an interactive session"
    def console(name = nil)
      Session::ConsoleRunner.new(name: name).run
    end

    desc "mcp", "Start the MCP server for AI agents"
    def mcp
      require_relative "mcp_server"
      McpServer.new.run
    end

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

      # Generate migration
      migration_gen = Generators::SQL::SqlMigrationGenerator.new(domain)
      migration = migration_gen.generate

      FileUtils.mkdir_p("db")
      File.write("db/schema.sql", migration)
      say "Generated db/schema.sql", :green

      # Generate SQL adapters into the domain gem
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

    desc "version", "Show current domain version"
    def version
      versioner = Versioner.new(".")
      say versioner.current
    end

    private

    def find_domain_file
      path = File.join(Dir.pwd, "domain.rb")
      File.exist?(path) ? path : nil
    end

    def load_domain(file)
      domain = eval(File.read(file), binding, file)
      domain.source_path = file
      domain
    end

    # Migration commands are in a separate file to keep this under 200 lines
    require_relative "cli/migration_commands"

    def domain_template(name)
      <<~RUBY
        Hecks.domain "#{name}" do
          aggregate "Example" do
            attribute :name, String

            validation :name, presence: true

            command "CreateExample" do
              attribute :name, String
            end
          end
        end
      RUBY
    end
  end
end
