require "spec_helper"

RSpec.describe Hecks::DomainModel::Aggregate do
  subject(:aggregate) do
    described_class.new(
      name: "Pizza",
      attributes: [name_attr],
      value_objects: [topping],
      commands: [create_command],
      validations: [Hecks::DomainModel::Validation.new(field: :name, rules: { presence: true })]
    )
  end

  let(:name_attr) do
    Hecks::DomainModel::Attribute.new(name: :name, type: String)
  end

  let(:topping) do
    Hecks::DomainModel::ValueObject.new(name: "Topping", attributes: [])
  end

  let(:create_command) do
    Hecks::DomainModel::Command.new(name: "CreatePizza", attributes: [name_attr])
  end

  describe "#value_objects" do
    it "contains value objects" do
      expect(aggregate.value_objects.map(&:name)).to eq(["Topping"])
    end
  end

  describe "#commands" do
    it "contains commands" do
      expect(aggregate.commands.map(&:name)).to eq(["CreatePizza"])
    end
  end
end
