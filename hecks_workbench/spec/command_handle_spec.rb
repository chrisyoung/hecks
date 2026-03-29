require "spec_helper"

RSpec.describe Hecks::Workbench::CommandHandle do
  let(:workbench) { Hecks::Workbench.new("Pizzas") }

  before { allow($stdout).to receive(:puts) }

  def build_handle
    pizza = workbench.aggregate("Pizza")
    pizza.create
  end

  describe "adding attributes" do
    it "adds a typed attribute to the command" do
      handle = build_handle
      handle.title String
      domain = workbench.to_domain
      cmd = domain.aggregates.first.commands.find { |c| c.name == "CreatePizza" }
      expect(cmd.attributes.map(&:name)).to include(:title)
    end

    it "adds a reference attribute to the command" do
      handle = build_handle
      handle.order_id({ reference: "Order" })
      domain = workbench.to_domain
      cmd = domain.aggregates.first.commands.find { |c| c.name == "CreatePizza" }
      attr = cmd.attributes.find { |a| a.name == :order_id }
      expect(attr).not_to be_nil
      expect(attr.reference?).to be true
    end

    it "adds a list attribute to the command" do
      handle = build_handle
      handle.tags({ list: String })
      domain = workbench.to_domain
      cmd = domain.aggregates.first.commands.find { |c| c.name == "CreatePizza" }
      attr = cmd.attributes.find { |a| a.name == :tags }
      expect(attr).not_to be_nil
      expect(attr.list?).to be true
    end

    it "returns self for chaining" do
      handle = build_handle
      result = handle.title String
      expect(result).to be(handle)
    end
  end

  describe "#inspect" do
    it "returns a compact representation" do
      handle = build_handle
      expect(handle.inspect).to eq("#<CreatePizza command on Pizza>")
    end
  end
end
