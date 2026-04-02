require "spec_helper"
require "hecks/benchmarks"
require "tmpdir"

RSpec.describe Hecks::Benchmarks do
  describe Hecks::Benchmarks::Timer do
    it "measures elapsed time in milliseconds" do
      elapsed, result = described_class.measure { 1 + 1 }
      expect(elapsed).to be_a(Float)
      expect(elapsed).to be >= 0
      expect(result).to eq(2)
    end
  end

  describe Hecks::Benchmarks::ResultStore do
    it "saves and loads results as JSON" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "bench.json")
        results = { domain: "test", build_ms: 1.5, timestamp: "2026-01-01" }
        described_class.save(results, path: path)

        loaded = described_class.load(path)
        expect(loaded[:domain]).to eq("test")
        expect(loaded[:build_ms]).to eq(1.5)
      end
    end

    it "returns nil when no results exist" do
      expect(described_class.load("/nonexistent/path.json")).to be_nil
    end

    it "appends multiple runs" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "bench.json")
        described_class.save({ run: 1 }, path: path)
        described_class.save({ run: 2 }, path: path)

        all = described_class.load_all(path)
        expect(all.size).to eq(2)
      end
    end
  end

  describe Hecks::Benchmarks::Suite do
    it "runs benchmarks against the pizzas example" do
      domain_path = File.join(File.expand_path("../../examples/pizzas", __dir__))
      suite = described_class.new(domain_path: domain_path, iterations: 2)
      results = suite.run

      expect(results[:domain]).to eq("pizzas")
      expect(results[:build_ms]).to be_a(Float)
      expect(results[:load_ms]).to be_a(Float)
      expect(results[:dispatch_ms]).to be_a(Float)
      expect(results[:timestamp]).to be_a(String)
    end

    describe ".check_regressions" do
      it "detects a 20%+ regression" do
        current = { build_ms: 15.0, load_ms: 10.0, dispatch_ms: 1.0 }
        baseline = { build_ms: 10.0, load_ms: 10.0, dispatch_ms: 1.0 }

        warnings = described_class.check_regressions(current, baseline)
        expect(warnings.size).to eq(1)
        expect(warnings.first).to include("build_ms")
        expect(warnings.first).to include("50%")
      end

      it "returns empty when within threshold" do
        current = { build_ms: 11.0, load_ms: 10.0, dispatch_ms: 1.0 }
        baseline = { build_ms: 10.0, load_ms: 10.0, dispatch_ms: 1.0 }

        warnings = described_class.check_regressions(current, baseline)
        expect(warnings).to be_empty
      end
    end
  end
end
