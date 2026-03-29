# Hecks::CLI
#
# Thor-based CLI. Commands are registered by each sub-gem via
# Hecks::CLI.register_command. No more god class — each module
# owns its own commands.
#
begin
  require "thor"
rescue LoadError
  raise LoadError, "The hecks CLI requires thor. Add gem 'thor' to your Gemfile."
end
require "fileutils"
require_relative "conflict_handler"
require_relative "domain_helpers"

module Hecks
  class CLI < Thor
    include ConflictHandler
    include DomainHelpers
    include HecksTemplating::NamingHelpers

    def self.exit_on_failure? = true

    # Command registry — sub-gems call this to register their commands.
    #
    #   Hecks::CLI.register_command(:build, "Generate the domain gem",
    #     options: { target: { type: :string, desc: "Build target" } }
    #   ) do |cli|
    #     domain = cli.resolve_domain_option
    #     # ...
    #   end
    #
    @pending_commands = []

    def self.register_command(name, description, options: {}, args: [], &block)
      @pending_commands << { name: name, description: description, options: options, args: args, block: block }
    end

    def self.pending_commands = @pending_commands

    # Called after all sub-gems have registered their commands.
    # Converts pending registrations into Thor commands.
    def self.install_commands!
      @pending_commands.each do |cmd|
        desc_args = cmd[:args].empty? ? cmd[:name].to_s : "#{cmd[:name]} #{cmd[:args].join(' ')}"
        desc desc_args, cmd[:description]
        cmd[:options].each { |name, opts| method_option name.to_s, **opts }
        define_method(cmd[:name], &cmd[:block])
      end
      @pending_commands = []
    end

    # Gem subcommand stays on CLI — it's about packaging hecks itself
    class Gem < Thor
    end

    class Docs < Thor
      desc "update", "Update all doc headers and markdown files"
      def update
        script = File.expand_path("../../../bin/update-docs", __FILE__)
        exec(script) if File.exist?(script)
        say "bin/update-docs not found", :red
      end
    end

    desc "docs SUBCOMMAND ...ARGS", "Documentation commands"
    subcommand "docs", Docs

    desc "gem SUBCOMMAND ...ARGS", "Gem packaging commands"
    subcommand "gem", Gem

    # Load and install all registered commands
    Dir[File.join(__dir__, "commands/*.rb")].each { |f| require f }
    install_commands!

    # Thor aliases for colon-separated command names
    map "generate:config"     => :generate_config
    map "generate:sinatra"    => :generate_sinatra
    map "generate:stub"       => :generate_stub
    map "generate:migrations" => :generate_migrations
    map "generate:sql"        => :generate_sql
    map "db:migrate"          => :db_migrate
    map "new"                 => :new_project
  end
end
