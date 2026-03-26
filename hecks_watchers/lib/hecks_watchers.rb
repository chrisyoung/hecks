# = HecksWatchers
#
# File watchers for Hecks development. Each watcher checks staged .rb files
# for a specific quality concern: file size, cross-component isolation,
# autoload registration, and spec coverage.
#
# == Usage
#
#   require "hecks_watchers"
#
#   # Run a single watcher
#   watcher = HecksWatchers::FileSize.new(project_root: Dir.pwd)
#   watcher.call
#
#   # Run all watchers in a polling loop
#   runner = HecksWatchers::Runner.new(project_root: Dir.pwd)
#   runner.start
#
require_relative "hecks_watchers/logger"
require_relative "hecks_watchers/file_size"
require_relative "hecks_watchers/cross_require"
require_relative "hecks_watchers/autoloads"
require_relative "hecks_watchers/spec_coverage"
require_relative "hecks_watchers/runner"
require_relative "hecks_watchers/log_reader"
