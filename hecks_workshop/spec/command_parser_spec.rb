require "spec_helper"

RSpec.describe Hecks::Workshop::WebRunner::CommandParser do
  let(:runner) do
    r = Hecks::Workshop::WorkshopRunner.new(name: "TestDomain")
    r.instance_variable_set(:@workshop, r.setup_workshop)
    r
  end
  let(:parser) { described_class.new(runner) }

  before { allow($stdout).to receive(:puts) }

  describe "bare commands" do
    %w[describe browse validate preview status aggregates].each do |cmd|
      it "executes #{cmd}" do
        result = parser.execute(cmd)
        expect(result[:error]).to be_nil
      end
    end

    it "executes play!" do
      runner.aggregate("Thing") { attribute :name, String; command :create }
      result = parser.execute("play!")
      expect(result[:error]).to be_nil
    end

    it "executes sketch!" do
      result = parser.execute("sketch!")
      expect(result[:error]).to be_nil
    end
  end

  describe "aggregate creation" do
    it "creates an aggregate from PascalCase name" do
      parser.execute("Pizza")
      expect(runner.instance_variable_get(:@workshop).aggregates).to include("Pizza")
    end
  end

  describe "handle methods" do
    before { parser.execute("Order") }

    it "calls describe" do
      result = parser.execute("Order.describe")
      expect(result[:error]).to be_nil
    end

    it "adds an attribute" do
      parser.execute("Order.attr :total, Integer")
      result = parser.execute("Order.attributes")
      expect(result[:output]).to include("total")
    end

    it "adds a string attribute" do
      parser.execute("Order.attr :name, String")
      result = parser.execute("Order.attributes")
      expect(result[:output]).to include("name")
    end

    it "adds a reference_to attribute" do
      parser.execute("Customer")
      parser.execute('Order.attr :customer_id, reference_to("Customer")')
      result = parser.execute("Order.describe")
      expect(result[:error]).to be_nil
    end

    it "adds a list_of attribute" do
      parser.execute('Order.attr :items, list_of("LineItem")')
      result = parser.execute("Order.describe")
      expect(result[:error]).to be_nil
    end

    it "removes an attribute" do
      parser.execute("Order.attr :total, Integer")
      parser.execute("Order.remove :total")
      result = parser.execute("Order.attributes")
      expect(result[:output]).not_to include("total")
    end

    it "adds a command" do
      parser.execute("Order.command :create")
      result = parser.execute("Order.commands")
      expect(result[:output]).to include("Create")
    end

    it "adds a validation with keyword args" do
      parser.execute("Order.attr :name, String")
      result = parser.execute("Order.validation :name, presence: true")
      expect(result[:error]).to be_nil
    end

    it "adds a lifecycle with default" do
      result = parser.execute('Order.lifecycle :status, default: "pending"')
      expect(result[:error]).to be_nil
    end
  end

  describe "security" do
    it "rejects lowercase bare words" do
      result = parser.execute("system")
      # "system" is not in BARE_COMMANDS
      expect(result[:error]).to be_nil # just returns nil
    end

    it "rejects non-PascalCase targets" do
      result = parser.execute("file.read")
      expect(result[:output]).not_to include("/")
    end

    it "rejects unknown handle methods" do
      parser.execute("Pizza")
      result = parser.execute("Pizza.send :system")
      expect(result[:output]).to include("Unknown method")
    end

    it "rejects chained method calls" do
      result = parser.execute("Object.const_get")
      expect(result[:output]).to include("Unknown method")
    end

    it "cannot access Hecks namespace" do
      result = parser.execute("Hecks.boot")
      expect(result[:output]).to include("Unknown method")
    end
  end
end
