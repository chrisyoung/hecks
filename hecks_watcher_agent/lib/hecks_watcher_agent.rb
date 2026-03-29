# HecksWatcherAgent
#
# Autonomous agent that reads watcher logs and creates PRs to fix issues.
# Simple fixes (autoloads, skeleton specs) are applied directly in Ruby.
# Complex fixes (file extraction, doc updates) delegate to Claude Code.
#
#   require "hecks_watcher_agent"
#   HecksWatcherAgent::Agent.new(project_root: Dir.pwd).call
#
module HecksWatcherAgent
end

require_relative "hecks_watcher_agent/agent"
