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
      # Starts an interactive REPL session for exploring and modifying a domain.
      #
      # Delegates to Session::ConsoleRunner, which provides a command-line
      # interface for executing commands, running queries, and inspecting
      # domain state in memory.
      #
      # @param name [String, nil] optional domain name or path to load
      # @return [void]
      def console(name = nil)
        Session::ConsoleRunner.new(name: name).run
      end
    end
  end
end
