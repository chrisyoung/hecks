require "spec_helper"

RSpec.describe "Closed Operations (HEC-71)" do
  let(:domain) do
    Hecks.domain "Finance" do
      aggregate "Account" do
        attribute :name, String

        value_object "Money" do
          attribute :amount, Integer
          attribute :currency, String

          operation :add, operator: :+ do |other|
            self.class.new(amount: amount + other.amount, currency: currency)
          end

          operation :subtract do |other|
            self.class.new(amount: amount - other.amount, currency: currency)
          end
        end

        command "CreateAccount" do
          attribute :name, String
        end
      end
    end
  end

  it "stores operations on the value object IR" do
    vo = domain.aggregates.first.value_objects.first
    expect(vo.operations.size).to eq(2)
    expect(vo.operations.first.name).to eq(:add)
    expect(vo.operations.first.operator).to eq(:+)
    expect(vo.operations.last.name).to eq(:subtract)
    expect(vo.operations.last.operator).to be_nil
  end

  it "generates operator methods on the value object class" do
    Hecks.load(domain)
    money_class = FinanceDomain::Account::Money
    a = money_class.new(amount: 10, currency: "USD")
    b = money_class.new(amount: 5, currency: "USD")

    result = a.add(b)
    expect(result.amount).to eq(15)
    expect(result.currency).to eq("USD")
    expect(result).to be_a(money_class)
  end

  it "aliases operator symbol" do
    Hecks.load(domain)
    money_class = FinanceDomain::Account::Money
    a = money_class.new(amount: 10, currency: "USD")
    b = money_class.new(amount: 3, currency: "USD")

    result = a + b
    expect(result.amount).to eq(13)
  end

  it "serializes operations in DSL round-trip" do
    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include("operation :add")
    expect(source).to include("operator: :+")
    expect(source).to include("operation :subtract")
  end
end
