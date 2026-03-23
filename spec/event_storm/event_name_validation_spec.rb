require "spec_helper"

RSpec.describe "Event name validation" do
  describe "when storm events match inferred events" do
    let(:source) do
      <<~STORM
        Command: [Place Order]
          Aggregate: (Order)
        Event: >>Placed Order<<
      STORM
    end

    it "produces no warnings" do
      result = Hecks::EventStorm::Parser.new(source).parse
      builder = Hecks::EventStorm::DomainBuilder.new(result, name: "Test")
      builder.build
      expect(result.warnings).to be_empty
    end
  end

  describe "when storm event has no matching command" do
    let(:source) do
      <<~STORM
        Command: [Place Order]
          Aggregate: (Order)
        Event: >>Order Shipped<<
      STORM
    end

    it "warns about unmatched events" do
      result = Hecks::EventStorm::Parser.new(source).parse
      builder = Hecks::EventStorm::DomainBuilder.new(result, name: "Test")
      builder.build
      expect(result.warnings).to include(
        a_string_matching(/OrderShipped.*no matching command/)
      )
    end
  end

  describe "end-to-end via Hecks.from_event_storm" do
    let(:source) do
      <<~STORM
        # My Domain

        Command: [Create Pizza]
          Aggregate: (Pizza)
        Event: >>Pizza Created<<

        Command: [Add Topping]
          Aggregate: (Pizza)
        Event: >>Topping Added<<
      STORM
    end

    it "returns both domain and DSL" do
      result = Hecks.from_event_storm(source, name: "Pizzas")
      expect(result.domain).to be_a(Hecks::DomainModel::Structure::Domain)
      expect(result.dsl).to include('Hecks.domain "Pizzas"')
      expect(result.domain.aggregates.map(&:name)).to include("Pizza")
    end

    it "warns about mismatched event names" do
      bad_source = <<~STORM
        Command: [Create Pizza]
          Aggregate: (Pizza)
        Event: >>Destroyed Pizza<<
      STORM

      result = Hecks.from_event_storm(bad_source, name: "Pizzas")
      expect(result.warnings).to include(
        a_string_matching(/DestroyedPizza.*no matching command/)
      )
    end
  end
end
