# Hecks::CLI::Domain#console
#
# Launches an interactive REPL session via Session::ConsoleRunner.
# Optionally accepts a domain name to load on startup.
#
#   hecks domain console [NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "console [NAME]", "Start an interactive session"
      def console(name = nil)
        Session::ConsoleRunner.new(name: name).run
      end
    end
  end
end
