# Hecks::CLI
#
# Thor-based command-line interface shell. Top-level dispatches to subcommands:
#   hecks domain <command>  -- domain lifecycle (build, serve, console, etc.)
#   hecks docs <command>    -- documentation tasks
#   hecks gem <command>     -- gem packaging (build, install)
#
begin
  require "thor"
rescue LoadError
  raise LoadError, "The hecks CLI requires thor. Add gem 'thor' to your Gemfile."
end
require "fileutils"
require_relative "conflict_handler"

module Hecks
  # Top-level CLI entry point. Inherits from Thor and registers subcommands
  # for domain lifecycle, documentation, and gem packaging. Includes
  # ConflictHandler for safe file writing with diff support.
  class CLI < Thor
    include ConflictHandler

    # Required by Thor to exit with non-zero status on failures.
    #
    # @return [Boolean] always true
    def self.exit_on_failure?
      true
    end

    # Top-level shortcuts for the most common commands.
    desc "init [NAME]", "Initialize a Hecks domain"
    def init(name = nil)
      Domain.start(["init"] + (name ? [name] : []))
    end

    desc "build", "Build the domain gem (shortcut for domain build)"
    option :target, type: :string, desc: "Build target: ruby, static, go, rails"
    def build
      Domain.start(["build"] + ARGV.drop(1))
    end

    desc "console [NAME]", "Start the interactive workbench"
    def console(name = nil)
      Domain.start(["console"] + (name ? [name] : []))
    end

    desc "serve", "Serve a domain over HTTP"
    def serve
      Domain.start(["serve"] + ARGV.drop(1))
    end

    desc "validate", "Validate the domain definition"
    def validate
      Domain.start(["validate"] + ARGV.drop(1))
    end

    desc "mcp", "Start MCP server for AI agents"
    def mcp
      Domain.start(["mcp"] + ARGV.drop(1))
    end

    desc "diff", "Show changes since last build"
    def diff
      Domain.start(["diff"] + ARGV.drop(1))
    end

    # Domain subcommand -- holds all domain lifecycle commands.
    # Shared helpers for domain resolution live here; individual commands
    # are loaded from cli/commands/*.rb and reopen this class.
    class Domain < Thor
      include ConflictHandler

      private

      # Finds hecks_domain.rb in the current working directory.
      #
      # @return [String, nil] the absolute path to hecks_domain.rb, or nil if not found
      def find_domain_file
        path = File.join(Dir.pwd, "hecks_domain.rb")
        File.exist?(path) ? path : nil
      end

      # Resolves a domain from a path, directory, file, subdirectory, or gem name.
      #
      # Resolution order:
      # 1. nil -> look for hecks_domain.rb in cwd
      # 2. directory -> look for hecks_domain.rb inside it
      # 3. file path -> load directly
      # 4. name -> check local subdirectory, then installed gems
      #
      # @param path_or_name [String, nil] a file path, directory, or gem name
      # @return [DomainModel::Structure::Domain, nil] the resolved domain, or nil
      def resolve_domain(path_or_name)
        if path_or_name.nil?
          file = find_domain_file
          return nil unless file
          load_domain(file)
        elsif File.directory?(path_or_name)
          file = File.join(path_or_name, "hecks_domain.rb")
          return nil unless File.exist?(file)
          load_domain(file)
        elsif File.exist?(path_or_name)
          load_domain(path_or_name)
        else
          # Check local subdirectory
          local = File.join(Dir.pwd, path_or_name, "hecks_domain.rb")
          if File.exist?(local)
            load_domain(local)
          else
            # Check installed gems
            resolve_domain_from_gem(path_or_name, version: options[:version])
          end
        end
      end

      # Resolves a domain from an installed RubyGem.
      #
      # Searches all gem specifications for ones containing hecks_domain.rb.
      # If multiple versions exist and no version is specified, prompts the
      # user interactively. Activates the gem and loads its domain file.
      #
      # @param gem_name [String] the gem name to search for
      # @param version [String, nil] optional version constraint
      # @return [DomainModel::Structure::Domain, nil] the loaded domain, or nil
      def resolve_domain_from_gem(gem_name, version: nil)
        specs = ::Gem::Specification.select { |s| s.name == gem_name && File.exist?(File.join(s.full_gem_path, "hecks_domain.rb")) }
        return nil if specs.empty?

        spec = if version
          specs.find { |s| s.version.to_s == version } || (say("Version #{version} not found", :red); return nil)
        elsif specs.size > 1
          specs.sort_by(&:version).reverse!
          say "Multiple versions of #{gem_name} installed:", :yellow
          specs.each_with_index { |s, i| say "  #{i + 1}. v#{s.version}" }
          choice = ask("Which version? [1-#{specs.size}]:")
          specs[choice.to_i - 1] || specs.first
        else
          specs.first
        end

        gem gem_name, "= #{spec.version}"
        require gem_name
        load_domain(File.join(spec.full_gem_path, "hecks_domain.rb"))
      rescue LoadError
        nil
      end

      # Resolves a domain using the --domain option or auto-detection.
      #
      # If --domain is provided, uses resolve_domain. Otherwise looks for
      # hecks_domain.rb in cwd, and if not found, lists installed domain gems
      # as suggestions.
      #
      # @return [DomainModel::Structure::Domain, nil] the resolved domain, or nil
      def resolve_domain_option
        if options[:domain]
          resolve_domain(options[:domain])
        else
          file = find_domain_file
          if file
            load_domain(file)
          else
            domains = find_installed_domains
            if domains.empty?
              say "No hecks_domain.rb found and no --domain specified.", :red
            else
              say "No hecks_domain.rb found. Use --domain to specify one:", :red
              domains.each do |name, versions|
                say "  --domain #{name} (#{versions.map { |v| "v#{v}" }.join(", ")})", :yellow
              end
            end
            nil
          end
        end
      end

      # Finds all installed gems that contain a hecks_domain.rb file.
      #
      # @return [Array<Array(String, Array<Gem::Version>)>] pairs of [gem_name, [versions]]
      #   sorted with newest versions first
      def find_installed_domains
        ::Gem::Specification.select do |spec|
          File.exist?(File.join(spec.full_gem_path, "hecks_domain.rb"))
        end.group_by(&:name).map do |name, specs|
          versions = specs.map(&:version).sort.reverse
          [name, versions]
        end
      end

      # Loads a domain from a file path by evaluating it with Kernel.load.
      #
      # Sets source_path on the domain after loading so generators know
      # where the domain definition lives on disk.
      #
      # @param file [String] absolute path to the hecks_domain.rb file
      # @return [DomainModel::Structure::Domain] the loaded domain
      def load_domain(file)
        Kernel.load(file)
        domain = Hecks.last_domain
        domain.source_path = file
        domain
      end

      # Generates a starter domain template for new projects.
      #
      # @param name [String] the PascalCase domain name
      # @return [String] the Ruby source code for a minimal hecks_domain.rb
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

    # Docs subcommand -- documentation tasks.
    class Docs < Thor
      desc "update", "Update all doc headers and markdown files"
      # Runs the bin/update-docs script to regenerate documentation.
      #
      # @return [void]
      def update
        script = File.expand_path("../../../bin/update-docs", __FILE__)
        unless File.exist?(script)
          say "bin/update-docs not found", :red
          return
        end
        exec script
      end
    end

    Dir[File.join(__dir__, "commands/*.rb")].each { |f| require f }

    desc "domain SUBCOMMAND ...ARGS", "Domain lifecycle commands"
    subcommand "domain", Domain

    desc "docs SUBCOMMAND ...ARGS", "Documentation commands"
    subcommand "docs", Docs

    desc "gem SUBCOMMAND ...ARGS", "Gem packaging commands"
    subcommand "gem", Gem
  end
end
