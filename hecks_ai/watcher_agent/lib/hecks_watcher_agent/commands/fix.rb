# HecksWatcherAgent CLI command
#
# Reads watcher log and creates a PR to fix reported issues.
#
#   hecks fix-watchers
#
require "hecks_watcher_agent"

Hecks::CLI.register_command(:"fix-watchers", "Read watcher log and create a PR to fix issues") do
  HecksWatcherAgent::Agent.new(project_root: Dir.pwd).call
end
