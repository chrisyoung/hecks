# HecksStats CLI Command
#
# Registers the `hecks stats` command. Loads all domain files in the
# current project and prints comprehensive metrics.
#
#   hecks stats
#   hecks stats --json
#
require "hecks_stats"

Hecks::CLI.register_command(:stats, "Show comprehensive domain statistics") do
  require "json" if options[:json]
  project_root = Dir.pwd
  stats = HecksStats::ProjectStats.new(project_root)
  if options[:json]
    puts JSON.pretty_generate(stats.to_h)
  else
    puts stats.summary
  end
end
