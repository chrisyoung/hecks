# Hecks::CLI::Domain#list
#
# Lists all installed Hecks domain gems found via RubyGems, showing
# gem names and available versions.
#
#   hecks domain list
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "list", "List installed Hecks domain gems"
      # Lists all installed Hecks domain gems.
      #
      # Searches all gem specifications for those containing hecks_domain.rb
      # and displays each gem name with its installed version(s).
      #
      # @return [void]
      def list
        domains = find_installed_domains
        if domains.empty?
          say "No Hecks domains installed.", :yellow
        else
          say "Installed Hecks domains:", :green
          domains.each do |name, versions|
            if versions.size == 1
              say "  #{name} (v#{versions.first})"
            else
              say "  #{name} (#{versions.map { |v| "v#{v}" }.join(", ")})"
            end
          end
        end
      end
    end
  end
end
