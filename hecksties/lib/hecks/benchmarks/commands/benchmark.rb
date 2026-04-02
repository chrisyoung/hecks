# Hecks Benchmark CLI Command
#
# Registers the `hecks benchmark` command. Runs build, load, and
# dispatch benchmarks against the current domain, stores results,
# and warns on regressions.
#
#   hecks benchmark
#   hecks benchmark --iterations 20
#   hecks benchmark --suite build
#
Hecks::CLI.register_command(:benchmark, "Run performance benchmarks",
  options: {
    iterations: { type: :numeric, default: 10, desc: "Iterations per suite" },
    suite:      { type: :string,  desc: "Run a single suite: build, load, or dispatch" },
    json:       { type: :boolean, desc: "Output results as JSON" }
  }
) do
  require "hecks/benchmarks"

  fmt = ->(seconds) { "%.2fms" % (seconds * 1000) }
  domain_dir = Dir.pwd
  bluebook = Dir[File.join(domain_dir, "*Bluebook")].first
  unless bluebook
    say "No Bluebook found in #{domain_dir}", :red
    next
  end

  iterations = options[:iterations] || 10
  suites = options[:suite] ? [options[:suite].to_sym] : Hecks::Benchmarks::SUITES

  results = {}
  suites.each do |suite|
    klass = Hecks::Benchmarks.const_get("#{suite.capitalize}Benchmark")
    say "Running #{suite} benchmark (#{iterations} iterations)..."
    results[suite] = klass.run(domain_dir: domain_dir, iterations: iterations)
  end

  store = Hecks::Benchmarks::ResultStore.new
  regressions = store.check_regressions(results)
  saved_path = store.save(results)

  if options[:json]
    require "json"
    puts JSON.pretty_generate(results.transform_values { |v| v.except(:times) })
  else
    results.each do |suite, timing|
      say ""
      say "#{suite.to_s.capitalize}:", :bold
      say "  min:    #{fmt.call(timing[:min])}"
      say "  median: #{fmt.call(timing[:median])}"
      say "  max:    #{fmt.call(timing[:max])}"
    end
    say ""
    say "Results saved to #{saved_path}", :green
  end

  next if regressions.empty?

  say ""
  say "REGRESSIONS DETECTED:", :red
  regressions.each do |r|
    say "  #{r[:suite]}: #{fmt.call(r[:previous_median])} -> " \
        "#{fmt.call(r[:current_median])} (+#{r[:pct_change]}%)", :red
  end
end
