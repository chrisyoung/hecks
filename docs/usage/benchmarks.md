# Benchmarks

Performance benchmarking suite for Hecks domains.

## CLI Usage

```bash
# Run benchmarks on current directory
hecks benchmark

# Specify domain path
hecks benchmark --domain examples/pizzas

# JSON output
hecks benchmark --format json

# Custom iterations
hecks benchmark --iterations 10

# Check against baseline
hecks benchmark --baseline benchmarks.json
```

## Output

```
Benchmark Results (pizzas, 5 iterations)
  Build:    3.45ms
  Load:     5.12ms
  Dispatch: 0.23ms

No regressions detected
Results saved to benchmarks.json
```

## Regression Detection

Results are saved to `benchmarks.json` after each run. Use `--baseline` to compare
against a previous run. A 20% regression threshold triggers warnings.

## Programmatic Usage

```ruby
require "hecks/benchmarks"

suite = Hecks::Benchmarks::Suite.new(domain_path: "examples/pizzas")
results = suite.run
# => { domain: "pizzas", build_ms: 3.45, load_ms: 5.12, dispatch_ms: 0.23, ... }

# Compare
baseline = Hecks::Benchmarks::ResultStore.load("benchmarks.json")
warnings = Hecks::Benchmarks::Suite.check_regressions(results, baseline)
```
