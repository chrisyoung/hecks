# Hecks::CLI#claude
#
# Starts file watchers, then launches Claude Code with permissions skipped.
# Watchers are cleaned up automatically when Claude exits. Any extra
# arguments are forwarded to the +claude+ CLI.
#
#   hecks claude
#   hecks claude --resume
#   hecks claude -p "fix the tests"
#
module Hecks
  class CLI < Thor
    desc "claude [ARGS...]", "Start file watchers and launch Claude Code"
    # Launches the hecks_claude script bundled with the gem,
    # forwarding any extra arguments to the claude CLI.
    #
    # @return [void]
    def claude(*args)
      script = ::Gem.bin_path("hecks", "hecks_claude")
      exec script, *args
    rescue ::Gem::Exception
      say "hecks_claude not found. Is the hecks gem installed?", :red
    end
  end
end
