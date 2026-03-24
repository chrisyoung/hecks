# Hecks::CLI::Domain#version
#
# Shows the Hecks framework version, or the version of a specific domain gem
# when --domain is provided (from RubyGems or the local CalVer version file).
#
#   hecks domain version [--domain NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "version", "Show Hecks version, or domain version (--domain)"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      def version
        if options[:domain]
          domain = resolve_domain(options[:domain])
          unless domain
            say "Domain not found: #{options[:domain]}", :red
            return
          end
          spec = Gem.loaded_specs[domain.gem_name]
          if spec
            say "#{domain.name}: #{spec.version}"
          else
            dir = File.directory?(options[:domain]) ? options[:domain] : "."
            versioner = Versioner.new(dir)
            say "#{domain.name}: #{versioner.current || "not built yet"}"
          end
        else
          say "hecks #{Hecks::VERSION}"
        end
      end
    end
  end
end
