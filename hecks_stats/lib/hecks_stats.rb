# HecksStats
#
# Comprehensive project statistics for Hecks domains.
# Provides domain model metrics: aggregates, commands, events,
# references, policies, actors, and relationship analysis.
#
#   stats = HecksStats::DomainStats.new(domain)
#   stats.summary   # => formatted string
#   stats.to_h      # => hash of all metrics
#
require_relative "hecks_stats/domain_stats"
require_relative "hecks_stats/project_stats"

module HecksStats
end
