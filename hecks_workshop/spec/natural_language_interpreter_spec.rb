require "spec_helper"

RSpec.describe Hecks::Workshop::NaturalLanguageInterpreter do
  let(:workshop) { Hecks.workshop("TestDomain") }
  let(:runner) do
    r = Hecks::Workshop::WorkshopRunner.new(name: "TestDomain")
    r.instance_variable_set(:@workshop, workshop)
    r
  end
  subject(:interp) { described_class.new(runner) }

  describe "#interpret" do
    it "adds an aggregate" do
      interp.interpret("add an aggregate called Pizza")
      expect(workshop.aggregate_builders.keys).to include("Pizza")
    end

    it "handles 'add aggregate' without article" do
      interp.interpret("add aggregate Order")
      expect(workshop.aggregate_builders.keys).to include("Order")
    end

    it "delegates validate" do
      expect(runner).to receive(:validate)
      interp.interpret("validate")
    end

    it "delegates build" do
      expect(runner).to receive(:build)
      interp.interpret("build")
    end

    it "delegates save" do
      expect(runner).to receive(:save)
      interp.interpret("save")
    end

    it "delegates describe/show/preview" do
      expect(runner).to receive(:describe)
      interp.interpret("describe")
    end

    it "returns nil for unrecognized phrases" do
      result = interp.interpret("make me a sandwich")
      expect(result).to be_nil
    end
  end
end
