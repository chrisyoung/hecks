# Hecks::CLI::Domain#console
#
# Launches the interactive Workbench via Workbench::ConsoleRunner.
# Optionally accepts a domain name to load on startup.
#
#   hecks domain console [NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "console [NAME]", "Start the interactive workbench"
      # Starts the interactive Workbench for domain modeling.
      #
      # Delegates to Workbench::ConsoleRunner, which provides a command-line
      # interface for sketching domains, playing with live objects, and
      # extending the runtime.
      #
      # @param name [String, nil] optional domain name or path to load
      # @return [void]
      def console(name = nil)
        Workbench::ConsoleRunner.new(name: name).run
      end
    end
  end
end
