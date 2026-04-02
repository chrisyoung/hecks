# Hecks::Benchmarks
#
# Performance benchmarking suite for Hecks domains. Measures build time,
# load time, and command dispatch latency. Results are stored as JSON
# for regression tracking.
#
#   Hecks::Benchmarks.run(domain)
#   Hecks::Benchmarks::ResultStore.load("benchmarks.json")
#
module Hecks
  module Benchmarks
    autoload :Timer,       "hecks/benchmarks/timer"
    autoload :Suite,       "hecks/benchmarks/suite"
    autoload :ResultStore, "hecks/benchmarks/result_store"
  end
end
