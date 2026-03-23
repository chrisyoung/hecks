# Hecks::CLI
#
# Thor-based command-line interface shell. Top-level dispatches to subcommands:
#   hecks domain <command>  — domain lifecycle (build, serve, console, etc.)
#   hecks docs <command>    — documentation tasks
#   hecks gem <command>     — gem packaging (build, install)
#
require "thor"
require "fileutils"

module Hecks
  class CLI < Thor
    # Domain subcommand — holds all domain lifecycle commands.
    # Shared helpers for domain resolution live here; individual commands
    # are loaded from cli/commands/*.rb and reopen this class.
    class Domain < Thor
      private

      def find_domain_file
        path = File.join(Dir.pwd, "hecks_domain.rb")
        File.exist?(path) ? path : nil
      end

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

      def find_installed_domains
        ::Gem::Specification.select do |spec|
          File.exist?(File.join(spec.full_gem_path, "hecks_domain.rb"))
        end.group_by(&:name).map do |name, specs|
          versions = specs.map(&:version).sort.reverse
          [name, versions]
        end
      end

      def load_domain(file)
        domain = eval(File.read(file), binding, file)
        domain.source_path = file
        domain
      end

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

    # Docs subcommand — documentation tasks
    class Docs < Thor
      desc "update", "Update all doc headers and markdown files"
      def update
        script = File.expand_path("../../../bin/update-docs", __FILE__)
        unless File.exist?(script)
          say "bin/update-docs not found", :red
          return
        end
        exec script
      end
    end

    Dir[File.join(__dir__, "cli/commands/*.rb")].each { |f| require f }

    desc "domain SUBCOMMAND ...ARGS", "Domain lifecycle commands"
    subcommand "domain", Domain

    desc "docs SUBCOMMAND ...ARGS", "Documentation commands"
    subcommand "docs", Docs

    desc "gem SUBCOMMAND ...ARGS", "Gem packaging commands"
    subcommand "gem", Gem
  end
end
