require "spec_helper"
require "ostruct"

RSpec.describe "Specifications" do
  describe Hecks::Specification do
    let(:high_value) do
      klass = Class.new do
        include Hecks::Specification

        def satisfied_by?(object)
          object.amount > 1000
        end
      end
      klass.new
    end

    let(:premium) do
      klass = Class.new do
        include Hecks::Specification

        def satisfied_by?(object)
          object.tier == "premium"
        end
      end
      klass.new
    end

    it "tests satisfied_by? with matching object" do
      obj = OpenStruct.new(amount: 5000)
      expect(high_value.satisfied_by?(obj)).to be true
    end

    it "tests satisfied_by? with non-matching object" do
      obj = OpenStruct.new(amount: 100)
      expect(high_value.satisfied_by?(obj)).to be false
    end

    it "provides a class-level satisfied_by? shortcut" do
      klass = Class.new do
        include Hecks::Specification
        def satisfied_by?(object)
          object.amount > 1000
        end
      end
      expect(klass.satisfied_by?(OpenStruct.new(amount: 5000))).to be true
      expect(klass.satisfied_by?(OpenStruct.new(amount: 100))).to be false
    end

    it "raises NotImplementedError for unimplemented satisfied_by?" do
      klass = Class.new { include Hecks::Specification }
      expect { klass.new.satisfied_by?(Object.new) }.to raise_error(NotImplementedError)
    end

    describe "and composition" do
      it "returns true when both specs are satisfied" do
        obj = OpenStruct.new(amount: 5000, tier: "premium")
        combo = high_value.and(premium)
        expect(combo.satisfied_by?(obj)).to be true
      end

      it "returns false when one spec is not satisfied" do
        obj = OpenStruct.new(amount: 5000, tier: "basic")
        combo = high_value.and(premium)
        expect(combo.satisfied_by?(obj)).to be false
      end
    end

    describe "or composition" do
      it "returns true when at least one spec is satisfied" do
        obj = OpenStruct.new(amount: 100, tier: "premium")
        combo = high_value.or(premium)
        expect(combo.satisfied_by?(obj)).to be true
      end

      it "returns false when neither spec is satisfied" do
        obj = OpenStruct.new(amount: 100, tier: "basic")
        combo = high_value.or(premium)
        expect(combo.satisfied_by?(obj)).to be false
      end
    end

    describe "not composition" do
      it "negates the specification" do
        obj = OpenStruct.new(amount: 100)
        negated = high_value.not
        expect(negated.satisfied_by?(obj)).to be true
      end

      it "negates a matching specification" do
        obj = OpenStruct.new(amount: 5000)
        negated = high_value.not
        expect(negated.satisfied_by?(obj)).to be false
      end
    end

    describe "complex composition" do
      it "supports chained composition" do
        obj = OpenStruct.new(amount: 100, tier: "basic")
        combo = high_value.not.and(premium.not)
        expect(combo.satisfied_by?(obj)).to be true
      end

      it "composed specs can be further composed" do
        obj = OpenStruct.new(amount: 5000, tier: "premium")
        combo = high_value.and(premium).not
        expect(combo.satisfied_by?(obj)).to be false
      end
    end
  end

  describe "DSL integration" do
    it "registers specifications on aggregates" do
      domain = Hecks.domain "TestSpecs" do
        aggregate "Order" do
          attribute :total, Float

          specification "HighValue" do |order|
            order.total > 1000
          end
        end
      end

      agg = domain.aggregates.first
      expect(agg.specifications.size).to eq(1)
      expect(agg.specifications.first.name).to eq("HighValue")
      expect(agg.specifications.first.block).to be_a(Proc)
    end

    it "supports multiple specifications on one aggregate" do
      domain = Hecks.domain "TestSpecs2" do
        aggregate "Account" do
          attribute :balance, Float

          specification "LowBalance" do |a|
            a.balance < 100
          end

          specification "HighBalance" do |a|
            a.balance > 10_000
          end
        end
      end

      agg = domain.aggregates.first
      expect(agg.specifications.size).to eq(2)
      expect(agg.specifications.map(&:name)).to eq(["LowBalance", "HighBalance"])
    end
  end

  describe "SpecificationGenerator" do
    it "generates a specification class with satisfied_by?" do
      spec = Hecks::DomainModel::Behavior::Specification.new(
        name: "HighRisk",
        block: proc { |loan| loan.principal > 50_000 }
      )
      gen = Hecks::Generators::Domain::SpecificationGenerator.new(
        spec, domain_module: "BankingDomain", aggregate_name: "Loan"
      )
      code = gen.generate
      expect(code).to include("module BankingDomain")
      expect(code).to include("class Loan")
      expect(code).to include("module Specifications")
      expect(code).to include("class HighRisk")
      expect(code).to include("def satisfied_by?(loan)")
    end
  end

  describe "DslSerializer" do
    it "serializes specifications" do
      domain = Hecks.domain "TestSerial" do
        aggregate "Loan" do
          attribute :principal, Float

          specification "HighRisk" do |loan|
            loan.principal > 50_000
          end
        end
      end

      serialized = Hecks::DslSerializer.new(domain).serialize
      expect(serialized).to include('specification "HighRisk"')
    end
  end

  describe "generated domain with specifications" do
    it "builds and loads specification classes" do
      domain = Hecks.domain "SpecTest" do
        aggregate "Widget" do
          attribute :weight, Float

          command "CreateWidget" do
            attribute :weight, Float
          end

          specification "Heavy" do |w|
            w.weight > 100
          end
        end
      end

      Hecks.build(domain, version: "1.0.0", output_dir: "/tmp/hecks_spec_test")
      $LOAD_PATH.unshift("/tmp/hecks_spec_test/spec_test_domain/lib")

      begin
        require "spec_test_domain"
        app = Hecks::Services::Runtime.new(domain)

        widget = Widget.create(weight: 150.0)
        spec_class = SpecTestDomain::Widget::Specifications::Heavy
        spec_instance = spec_class.new
        expect(spec_instance).to respond_to(:satisfied_by?)
        expect(spec_instance.satisfied_by?(widget)).to be true

        light = Widget.create(weight: 10.0)
        expect(spec_instance.satisfied_by?(light)).to be false
      ensure
        $LOAD_PATH.delete("/tmp/hecks_spec_test/spec_test_domain/lib")
        FileUtils.rm_rf("/tmp/hecks_spec_test")
        Object.send(:remove_const, :SpecTestDomain) if defined?(SpecTestDomain)
      end
    end
  end
end
