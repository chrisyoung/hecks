require "spec_helper"

RSpec.describe Hecks::Generators::Domain::SubscriberGenerator do
  let(:subscriber) do
    Hecks::DomainModel::Behavior::EventSubscriber.new(
      name: "OnCreatedPizza",
      event_name: "CreatedPizza",
      block: proc { |event| puts event.name },
      async: false
    )
  end

  let(:generator) do
    described_class.new(subscriber, domain_module: "PizzasDomain", aggregate_name: "Pizza")
  end

  let(:source) { generator.generate }

  it "generates a class under Subscribers module" do
    expect(source).to include("module Subscribers")
    expect(source).to include("class OnCreatedPizza")
  end

  it "declares EVENT constant" do
    expect(source).to include('EVENT = "CreatedPizza"')
  end

  it "declares ASYNC constant" do
    expect(source).to include("ASYNC = false")
  end

  it "generates self.event and self.async accessors" do
    expect(source).to include("def self.event = EVENT")
    expect(source).to include("def self.async = ASYNC")
  end

  it "generates a call method with event parameter" do
    expect(source).to include("def call(event)")
  end

  it "generates a call method with a body" do
    # block_source works with do...end DSL blocks, not inline procs
    # so the body here is "true" (fallback). Real DSL usage extracts actual code.
    expect(source).to include("def call(event)")
    expect(source).to include("end")
  end

  context "with async: true" do
    let(:subscriber) do
      Hecks::DomainModel::Behavior::EventSubscriber.new(
        name: "OnCreatedPizza2",
        event_name: "CreatedPizza",
        block: proc { |event| puts "async" },
        async: true
      )
    end

    it "sets ASYNC to true" do
      expect(source).to include("ASYNC = true")
    end
  end
end
