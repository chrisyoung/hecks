require "hecks"
require "hecks/benchmarks"

RSpec.describe Hecks::Benchmarks, :slow do
  let(:pizzas_dir) { File.expand_path("../../../examples/pizzas", __dir__) }

  describe "BuildBenchmark" do
    it "measures domain build time" do
      result = Hecks::Benchmarks::BuildBenchmark.run(
        domain_dir: pizzas_dir, iterations: 2
      )

      expect(result[:min]).to be > 0
      expect(result[:median]).to be > 0
      expect(result[:times].length).to eq(2)
    end
  end

  describe "LoadBenchmark" do
    it "measures domain load time" do
      result = Hecks::Benchmarks::LoadBenchmark.run(
        domain_dir: pizzas_dir, iterations: 2
      )

      expect(result[:min]).to be > 0
      expect(result[:median]).to be > 0
    end
  end

  describe "DispatchBenchmark" do
    it "measures command dispatch time" do
      result = Hecks::Benchmarks::DispatchBenchmark.run(
        domain_dir: pizzas_dir, iterations: 2
      )

      expect(result[:min]).to be > 0
      expect(result[:median]).to be > 0
    end
  end

  describe ".run_all" do
    it "runs all suites and returns combined results" do
      results = described_class.run_all(domain_dir: pizzas_dir, iterations: 2)

      expect(results.keys).to contain_exactly(:build, :load, :dispatch)
      results.each_value do |timing|
        expect(timing[:median]).to be > 0
      end
    end
  end
end
