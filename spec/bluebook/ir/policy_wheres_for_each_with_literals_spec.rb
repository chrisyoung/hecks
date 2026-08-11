require "hecksagain"

RSpec.describe Hecksagain::Bluebook::IR::Policy do
  describe "with_literals/wheres/for_each" do
    it "accepts and reads back all three, defaulting to empty/nil when not given" do
      bare = described_class.new(name: "Bare", on_event: "Thing.Happened", trigger_command: "Thing.React")

      expect(bare.with_literals).to eq({})
      expect(bare.wheres).to eq({})
      expect(bare.for_each).to be_nil

      full = described_class.new(
        name: "Full", on_event: "Thing.Happened", trigger_command: "Thing.React",
        with_literals: { "kind" => "urgent" }, wheres: { status: "critical" },
        for_each: { from: "Thing.Rows", where: {} }
      )

      expect(full.with_literals).to eq("kind" => "urgent")
      expect(full.wheres).to eq(status: "critical")
      expect(full.for_each).to eq(from: "Thing.Rows", where: {})
    end
  end
end
