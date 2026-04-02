require_relative "../spec_helper"
require "hecks/test_helper/property_testing"

RSpec.describe Hecks::TestHelper::PropertyTesting do
  let(:domain) { BootedDomains.pizzas }
  let(:pizza_agg) { domain.aggregates.find { |a| a.name == "Pizza" } }
  let(:order_agg) { domain.aggregates.find { |a| a.name == "Order" } }

  describe Hecks::TestHelper::PropertyTesting::TypeGenerators do
    subject(:gen) { described_class.new(seed: 42) }

    it "generates strings" do
      val = gen.generate(String)
      expect(val).to be_a(String)
      expect(val).to start_with("prop_")
    end

    it "generates integers" do
      val = gen.generate(Integer)
      expect(val).to be_a(Integer)
      expect(val).to be_between(1, 10_000)
    end

    it "generates floats" do
      val = gen.generate(Float)
      expect(val).to be_a(Float)
    end

    it "generates dates" do
      val = gen.generate(Date)
      expect(val).to be_a(Date)
    end

    it "generates datetimes" do
      val = gen.generate(DateTime)
      expect(val).to be_a(DateTime)
    end

    it "generates JSON hashes" do
      val = gen.generate(JSON)
      expect(val).to be_a(Hash)
    end

    it "generates reference UUIDs for unknown string types" do
      val = gen.generate("Pizza")
      expect(val).to be_a(String)
      expect(val).to match(/\A[0-9a-f]{8}-/)
    end

    it "is reproducible with the same seed" do
      gen1 = described_class.new(seed: 99)
      gen2 = described_class.new(seed: 99)
      5.times do
        expect(gen1.generate(String)).to eq(gen2.generate(String))
      end
    end

    it "generates for list attributes" do
      list_attr = pizza_agg.attributes.find { |a| a.list? }
      next skip("no list attribute found") unless list_attr

      val = gen.generate_for_attribute(list_attr)
      expect(val).to be_an(Array)
    end

    it "generates for enum attributes" do
      enum_attr = Hecks::DomainModel::Structure::Attribute.new(
        name: :status, type: String, enum: %w[active inactive]
      )
      val = gen.generate_for_attribute(enum_attr)
      expect(%w[active inactive]).to include(val)
    end
  end

  describe Hecks::TestHelper::PropertyTesting::AggregateGenerator do
    subject(:gen) { described_class.new(pizza_agg, seed: 42) }

    it "generates N attribute hashes" do
      hashes = gen.generate(5)
      expect(hashes.size).to eq(5)
      hashes.each do |h|
        expect(h).to be_a(Hash)
        expect(h).to have_key(:name)
      end
    end

    it "generates a single hash" do
      h = gen.generate_one
      expect(h).to be_a(Hash)
      expect(h[:name]).to be_a(String)
    end

    it "generates for a specific command" do
      hashes = gen.generate_for_command("CreatePizza", 3)
      expect(hashes.size).to eq(3)
      hashes.each do |h|
        expect(h).to have_key(:name)
        expect(h).to have_key(:style)
      end
    end

    it "raises on unknown command" do
      expect { gen.generate_for_command("Nonexistent", 1) }
        .to raise_error(ArgumentError, /Unknown command/)
    end

    it "is reproducible" do
      gen1 = described_class.new(pizza_agg, seed: 77)
      gen2 = described_class.new(pizza_agg, seed: 77)
      expect(gen1.generate(3)).to eq(gen2.generate(3))
    end

    it "exposes the seed" do
      expect(gen.seed).to eq(42)
    end
  end

  describe Hecks::TestHelper::PropertyTesting::DomainFuzzer do
    let(:runtime) { Hecks.load(domain) }

    it "runs fuzz tests and produces a report" do
      fuzzer = described_class.new(domain, runtime, seed: 42)
      report = fuzzer.run(iterations: 5)

      expect(report).to be_a(Hecks::TestHelper::PropertyTesting::FuzzReport)
      expect(report.results).not_to be_empty
      expect(report.summary).to match(/\d+\/\d+ passed/)
    end

    it "reports seed for reproducibility" do
      fuzzer = described_class.new(domain, runtime, seed: 123)
      report = fuzzer.run(iterations: 2)
      expect(report.seed).to eq(123)
    end
  end

  describe "RSpec integration" do
    include Hecks::TestHelper::PropertyTesting::RSpecHelpers

    it "provides property_test helper" do
      tested = 0
      property_test(pizza_agg, count: 10, seed: 42) do |attrs|
        expect(attrs[:name]).to be_a(String)
        tested += 1
      end
      expect(tested).to eq(10)
    end

    it "provides survive_fuzz_testing matcher" do
      runtime = Hecks.load(domain)
      expect([domain, runtime]).to survive_fuzz_testing(iterations: 5, seed: 42)
    end
  end
end
