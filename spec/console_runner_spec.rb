require "spec_helper"

RSpec.describe Hecks::Session::ConsoleRunner do
  let(:runner) { described_class.new }

  before do
    allow($stdout).to receive(:puts)
    runner.instance_variable_set(:@session, Hecks::Session.new("Test"))
  end

  describe "#aggregate" do
    it "delegates to session" do
      handle = runner.aggregate("Cat")
      expect(handle).to be_a(Hecks::Session::AggregateHandle)
    end

    it "normalizes lowercase names" do
      handle = runner.aggregate("cat")
      expect(handle.name).to eq("Cat")
    end
  end

  describe "#_a" do
    it "returns the last aggregate handle" do
      runner.aggregate("Cat")
      runner.aggregate("Dog")
      expect(runner._a.name).to eq("Dog")
    end

    it "is nil before any aggregate" do
      expect(runner._a).to be_nil
    end
  end

  describe "#help" do
    it "prints help text" do
      expect { runner.help }.to output(/aggregate.*validate.*build/m).to_stdout
    end

    it "returns nil" do
      expect(runner.help).to be_nil
    end
  end

  describe "delegated methods" do
    it "delegates validate" do
      runner.aggregate("Cat") { attribute :name, String; command("AdoptCat") { attribute :name, String } }
      expect(runner.validate).to be true
    end

    it "delegates describe" do
      runner.aggregate("Cat") { attribute :name, String }
      expect { runner.describe }.to output(/Test Domain/).to_stdout
    end

    it "delegates aggregates" do
      runner.aggregate("Cat")
      runner.aggregate("Dog")
      expect(runner.aggregates).to eq(["Cat", "Dog"])
    end

    it "delegates remove" do
      runner.aggregate("Cat")
      runner.remove("Cat")
      expect(runner.aggregates).to be_empty
    end

    it "delegates add_verb" do
      runner.add_verb("Poop")
      domain = runner.send(:instance_variable_get, :@session).to_domain
      expect(domain.custom_verbs).to include("Poop")
    end
  end
end
