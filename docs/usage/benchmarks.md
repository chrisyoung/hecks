# Benchmarks

Measure build, load, and dispatch performance of your Hecks domain.

## CLI Usage

Run from a directory containing a Bluebook file:

```bash
# Run all three suites (build, load, dispatch) with 10 iterations each
hecks benchmark

# Run only the build benchmark with 20 iterations
hecks benchmark --suite build --iterations 20

# Output results as JSON
hecks benchmark --json
```

## Output

```
Running build benchmark (10 iterations)...
Running load benchmark (10 iterations)...
Running dispatch benchmark (10 iterations)...

Build:
  min:    32.15ms
  median: 34.82ms
  max:    41.07ms

Load:
  min:    8.21ms
  median: 9.44ms
  max:    12.30ms

Dispatch:
  min:    0.31ms
  median: 0.38ms
  max:    0.52ms

Results saved to tmp/benchmarks/benchmark_20260401_120000.json
```

## Regression Detection

Results are saved as JSON in `tmp/benchmarks/`. On each run, the tool
compares the current median against the previous run. If any suite
regresses by more than 20%, a warning is printed:

```
REGRESSIONS DETECTED:
  build: 34.82ms -> 45.10ms (+29.5%)
```

## Programmatic API

```ruby
require "hecks/benchmarks"

# Run all suites
results = Hecks::Benchmarks.run_all(domain_dir: ".", iterations: 10)
results[:build][:median]  # => 0.03482

# Run a single suite
timing = Hecks::Benchmarks::BuildBenchmark.run(domain_dir: ".", iterations: 5)
timing[:min]    # => 0.03215
timing[:median] # => 0.03482
timing[:max]    # => 0.04107

# Store and check regressions
store = Hecks::Benchmarks::ResultStore.new
store.save(results)
regressions = store.check_regressions(results)
```

## Suites

| Suite      | What it measures                                      |
|------------|-------------------------------------------------------|
| `build`    | Time to generate a domain gem from Bluebook            |
| `load`     | Time to parse Bluebook and wire a runtime (in-memory)  |
| `dispatch` | Time to dispatch a single command through the bus      |
