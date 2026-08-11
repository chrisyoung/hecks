require "hecksagain"

RSpec.describe Hecksagain::Bluebook::DSL::PolicyBuilder do
  describe "with_literals wiring" do
    it "carries repeated with(key, value) calls into IR::Policy#with_literals" do
      policy = described_class.build("Grants") do
        on "Thing.Happened"
        trigger "Thing.React"
        with "kind", "urgent"
        with "source", "growth"
      end

      expect(policy.with_literals).to eq("kind" => "urgent", "source" => "growth")
    end

    it "folds map's field selections into the same with_literals accumulator" do
      policy = described_class.build("Mapped") do
        on "Thing.Happened"
        trigger "Thing.React"
        map target: :event_field
      end

      expect(policy.with_literals).to eq("target" => :event_field)
    end
  end

  describe "description/condition/cross_domain stubs" do
    it "accepts each and builds a policy unaffected, deliberate no-ops" do
      policy = described_class.build("Stubbed") do
        description "prose only"
        on "Thing.Happened"
        trigger "Thing.React"
        condition { |event| event.severity == "critical" }
        cross_domain true
      end

      expect(policy).to be_a(Hecksagain::Bluebook::IR::Policy)
      expect(policy.name).to eq("Stubbed")
    end
  end
end
