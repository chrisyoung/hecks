# Hecks::CLI -- benchmark command
#
# Runs performance benchmarks against the domain (build, load, dispatch)
# and optionally compares against a stored baseline for regression detection.
#
#   hecks benchmark
#   hecks benchmark --domain path/to/domain
#   hecks benchmark --baseline benchmarks.json
#
require "hecks/benchmarks"

Hecks::CLI.register_command(:benchmark, "Run performance benchmarks",
  options: {
    domain: { type: :string, desc: "Domain path (default: current directory)" },
    baseline: { type: :string, desc: "Path to baseline JSON for regression check" },
    format: { type: :string, desc: "Output format: text (default) or json" },
    iterations: { type: :numeric, desc: "Number of iterations (default: 5)" }
  }
) do
  domain_path = options[:domain] || Dir.pwd
  iterations = options[:iterations] || 5

  suite = Hecks::Benchmarks::Suite.new(domain_path: domain_path, iterations: iterations)
  results = suite.run

  if options[:format] == "json"
    require "json"
    say JSON.pretty_generate(results)
    next
  end

  say "Benchmark Results (#{results[:domain]}, #{results[:iterations]} iterations)", :bold
  say "  Build:    #{fmt(results[:build_ms])}"
  say "  Load:     #{fmt(results[:load_ms])}"
  say "  Dispatch: #{fmt(results[:dispatch_ms])}"

  if options[:baseline]
    baseline = Hecks::Benchmarks::ResultStore.load(options[:baseline])
    if baseline
      regressions = Hecks::Benchmarks::Suite.check_regressions(results, baseline)
      if regressions.empty?
        say "\nNo regressions detected", :green
      else
        say "\nRegressions:", :red
        regressions.each { |r| say "  - #{r}", :red }
      end
    else
      say "\nNo baseline found at #{options[:baseline]}", :yellow
    end
  end

  Hecks::Benchmarks::ResultStore.save(results)
  say "\nResults saved to benchmarks.json"
end

def fmt(ms)
  ms ? "#{"%.2f" % ms}ms" : "N/A"
end
