# Hecks::CLI list command
#
module Hecks
  class CLI < Thor
    desc "list", "List installed Hecks domain gems"
    def list
      domains = find_installed_domains
      if domains.empty?
        say "No Hecks domains installed.", :yellow
      else
        say "Installed Hecks domains:", :green
        domains.each { |name, ver| say "  #{name} (v#{ver})" }
      end
    end
  end
end
