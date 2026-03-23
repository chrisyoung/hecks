# Hecks::CLI version command
#
module Hecks
  class CLI < Thor
    desc "version [DOMAIN]", "Show Hecks version, or domain version if given"
    def version(domain_path = nil)
      if domain_path
        domain = resolve_domain(domain_path)
        unless domain
          say "Domain not found: #{domain_path}", :red
          return
        end
        # Check gem version first, then local .hecks_version
        spec = Gem.loaded_specs[domain.gem_name] rescue nil
        if spec
          say "#{domain.name}: #{spec.version}"
        else
          dir = File.directory?(domain_path) ? domain_path : File.dirname(domain_path)
          versioner = Versioner.new(dir)
          say "#{domain.name}: #{versioner.current || "not built yet"}"
        end
      else
        say "hecks #{Hecks::VERSION}"
      end
    end
  end
end
