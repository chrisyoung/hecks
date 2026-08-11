require "hecksagain"

RSpec.describe Hecksagain::Bluebook::IR::Command do
  describe "redirects_native" do
    it "round-trips through declare/absorb into to_h" do
      verb = described_class.declare(
        name: "Read",
        role: "Agent",
        goal: "read a file",
        redirects_native: ["FileTool.Read"]
      )

      expect(verb.redirects_native).to eq(["FileTool.Read"])
      expect(verb.to_h[:redirects_native]).to eq(["FileTool.Read"])
    end

    it "defaults to an empty list when not declared" do
      verb = described_class.declare(name: "Noop", role: "Agent", goal: "do nothing")

      expect(verb.redirects_native).to eq([])
      expect(verb.to_h[:redirects_native]).to eq([])
    end
  end
end
