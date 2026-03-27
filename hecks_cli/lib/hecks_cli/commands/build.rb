# Hecks::CLI::Domain#build
#
# Validates the domain, assigns a CalVer version, and generates the domain gem.
# Outputs the gem directory path and docs location on success.
#
#   hecks domain build [--domain NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "build", "Generate the domain gem"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      option :static, type: :boolean, desc: "Generate static gem with no hecks dependency"
      # Validates the domain definition, assigns a CalVer version, and generates
      # the domain gem with all aggregates, commands, and documentation.
      #
      # Exits with status 1 if no domain file is found. Prints validation errors
      # and returns early if the domain is invalid.
      #
      # @return [void]
      def build
        domain = resolve_domain_option
        unless domain
          say "Error: must be run from a directory containing hecks_domain.rb", :red
          raise SystemExit.new(1)
        end
        validator = Validator.new(domain)
        unless validator.valid?
          say "Domain validation failed:", :red
          validator.errors.each { |e| say "  - #{e}", :red }
          return
        end
        versioner = Versioner.new(".")
        version = versioner.next
        if options[:static]
          output = Hecks.build_static(domain, version: version)
          say "Built #{domain.gem_name} v#{version} (static)", :green
        else
          output = Hecks.build(domain, version: version)
          say "Built #{domain.gem_name} v#{version}", :green
          say "  Docs: #{output}/docs/"
        end
        say "  Output: #{output}/"
      end
    end
  end
end
