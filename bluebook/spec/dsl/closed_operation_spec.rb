require "spec_helper"

RSpec.describe "closed operations on value objects" do
  describe "DSL parsing" do
    it "parses operation keyword and builds IR" do
      domain = Hecks.domain("Finance") do
        aggregate("Account") do
          attribute :balance, Float
          value_object "Money" do
            attribute :amount, Integer
            attribute :currency, String
            operation(:+) { |other| { amount: amount + other.amount, currency: currency } }
          end
          command("CreateAccount") { attribute :balance, Float }
        end
      end

      vo = domain.aggregates.first.value_objects.first
      expect(vo.operations.size).to eq(1)

      op = vo.operations.first
      expect(op.name).to eq(:+)
      expect(op.block).to be_a(Proc)
    end

    it "supports multiple operations" do
      domain = Hecks.domain("Finance") do
        aggregate("Account") do
          attribute :balance, Float
          value_object "Money" do
            attribute :amount, Integer
            attribute :currency, String
            operation(:+) { |other| { amount: amount + other.amount, currency: currency } }
            operation(:-) { |other| { amount: amount - other.amount, currency: currency } }
          end
          command("CreateAccount") { attribute :balance, Float }
        end
      end

      expect(domain.aggregates.first.value_objects.first.operations.size).to eq(2)
    end

    it "supports named method operations" do
      domain = Hecks.domain("Shipping") do
        aggregate("Package") do
          attribute :label, String
          value_object "Weight" do
            attribute :grams, Integer
            operation(:combine) { |other| { grams: grams + other.grams } }
          end
          command("CreatePackage") { attribute :label, String }
        end
      end

      op = domain.aggregates.first.value_objects.first.operations.first
      expect(op.name).to eq(:combine)
    end
  end

  describe "defaults" do
    it "defaults operations to empty array" do
      domain = Hecks.domain("Simple") do
        aggregate("Thing") do
          attribute :name, String
          value_object("Tag") { attribute :label, String }
          command("CreateThing") { attribute :name, String }
        end
      end

      expect(domain.aggregates.first.value_objects.first.operations).to eq([])
    end
  end

  describe "Ruby code generation" do
    it "generates operator methods on value object class" do
      domain = Hecks.domain("Finance") do
        aggregate("Account") do
          attribute :balance, Float
          value_object "Money" do
            attribute :amount, Integer
            attribute :currency, String
            operation(:+) { |other| { amount: amount + other.amount, currency: currency } }
          end
          command("CreateAccount") { attribute :balance, Float }
        end
      end

      gen = Hecks::Generators::Domain::ValueObjectGenerator.new(
        domain.aggregates.first.value_objects.first,
        domain_module: "FinanceDomain", aggregate_name: "Account"
      )
      code = gen.generate

      expect(code).to include("def +(other)")
      expect(code).to include("self.class.new(instance_exec(other, &proc {")
      expect(code).to include("# Closed operations -- return same type")
    end

    it "omits operations section when none defined" do
      domain = Hecks.domain("Simple") do
        aggregate("Thing") do
          attribute :name, String
          value_object("Tag") { attribute :label, String }
          command("CreateThing") { attribute :name, String }
        end
      end

      gen = Hecks::Generators::Domain::ValueObjectGenerator.new(
        domain.aggregates.first.value_objects.first,
        domain_module: "SimpleDomain", aggregate_name: "Thing"
      )
      code = gen.generate

      expect(code).not_to include("Closed operations")
    end
  end

  describe "serializer round-trip" do
    it "serializes operations to DSL source" do
      domain = Hecks.domain("Finance") do
        aggregate("Account") do
          attribute :balance, Float
          value_object "Money" do
            attribute :amount, Integer
            attribute :currency, String
            operation(:+) { |other| { amount: amount + other.amount, currency: currency } }
          end
          command("CreateAccount") { attribute :balance, Float }
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include("operation :+")
    end
  end
end
