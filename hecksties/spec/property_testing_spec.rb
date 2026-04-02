require "spec_helper"
require "hecks/property_testing"

RSpec.describe Hecks::PropertyTesting do
  describe Hecks::PropertyTesting::TypeGenerator do
    subject(:gen) { described_class.new(seed: 42) }

    it "generates reproducible strings" do
      a = described_class.new(seed: 42).string
      b = described_class.new(seed: 42).string
      expect(a).to eq(b)
    end

    it "generates strings of 4-12 characters" do
      100.times do
        s = gen.string
        expect(s.length).to be_between(4, 12)
      end
    end

    it "generates integers" do
      val = gen.integer
      expect(val).to be_a(Integer)
    end

    it "generates values for Hecks types" do
      expect(gen.for_type(String)).to be_a(String)
      expect(gen.for_type(Integer)).to be_a(Integer)
      expect(gen.for_type(Float)).to be_a(Float)
      expect([true, false]).to include(gen.for_type("Boolean"))
    end
  end

  describe Hecks::PropertyTesting::AggregateGenerator do
    let(:domain) do
      Hecks.domain("Test") do
        aggregate("Widget") do
          attribute :name, String
          attribute :count, Integer
          command("CreateWidget") do
            attribute :name, String
            attribute :count, Integer
          end
        end
      end
    end

    subject(:gen) { described_class.new(domain.aggregates.first, seed: 42) }

    it "generates command attributes matching types" do
      attrs = gen.command_attrs("CreateWidget")
      expect(attrs[:name]).to be_a(String)
      expect(attrs[:count]).to be_a(Integer)
    end

    it "generates multiple samples" do
      samples = gen.samples("CreateWidget", count: 5)
      expect(samples.size).to eq(5)
      expect(samples.map { |s| s[:name] }.uniq.size).to be > 1
    end

    it "generates root attributes" do
      attrs = gen.root_attrs
      expect(attrs[:name]).to be_a(String)
      expect(attrs[:count]).to be_a(Integer)
    end
  end

  describe Hecks::PropertyTesting::DomainFuzzer do
    let(:domain) do
      Hecks.domain("FuzzTest") do
        aggregate("Thing") do
          attribute :name, String
          command("CreateThing") { attribute :name, String }
        end
      end
    end

    it "fuzzes a domain and reports results" do
      fuzzer = described_class.new(domain, seed: 42, rounds: 10)
      report = fuzzer.run

      expect(report[:seed]).to eq(42)
      expect(report[:rounds]).to eq(10)
      expect(report[:successes]).to be > 0
      expect(report[:failures]).to be_an(Array)
    end

    it "produces reproducible results with same seed" do
      a = described_class.new(domain, seed: 99, rounds: 5).run
      b = described_class.new(domain, seed: 99, rounds: 5).run
      expect(a[:successes]).to eq(b[:successes])
    end
  end
end
