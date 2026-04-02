require "hecks"
require "hecks/benchmarks"
require "tmpdir"

RSpec.describe Hecks::Benchmarks::ResultStore do
  let(:tmpdir) { Dir.mktmpdir }
  let(:store)  { described_class.new(dir: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  def sample_results(build_median: 0.05, load_median: 0.01, dispatch_median: 0.001)
    {
      build:    { min: build_median * 0.9, median: build_median, max: build_median * 1.1, times: [build_median] },
      load:     { min: load_median * 0.9, median: load_median, max: load_median * 1.1, times: [load_median] },
      dispatch: { min: dispatch_median * 0.9, median: dispatch_median, max: dispatch_median * 1.1, times: [dispatch_median] }
    }
  end

  it "saves results to a JSON file" do
    path = store.save(sample_results)

    expect(File.exist?(path)).to be true
    data = JSON.parse(File.read(path), symbolize_names: true)
    expect(data[:build][:median]).to eq(0.05)
    expect(data[:build]).not_to have_key(:times)
  end

  it "loads the latest result" do
    store.save(sample_results(build_median: 0.04))
    sleep 0.01
    store.save(sample_results(build_median: 0.05))

    latest = store.latest
    expect(latest[:build][:median]).to eq(0.05)
  end

  it "returns nil when no previous results exist" do
    expect(store.latest).to be_nil
  end

  it "detects regressions above 20% threshold" do
    store.save(sample_results(build_median: 0.05))

    regressed = sample_results(build_median: 0.07)
    regressions = store.check_regressions(regressed)

    expect(regressions.length).to eq(1)
    expect(regressions.first[:suite]).to eq(:build)
    expect(regressions.first[:pct_change]).to eq(40.0)
  end

  it "reports no regressions when within threshold" do
    store.save(sample_results(build_median: 0.05))

    stable = sample_results(build_median: 0.055)
    regressions = store.check_regressions(stable)

    expect(regressions).to be_empty
  end

  it "returns empty regressions when no previous run exists" do
    regressions = store.check_regressions(sample_results)
    expect(regressions).to be_empty
  end
end
