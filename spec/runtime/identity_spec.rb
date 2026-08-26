require "hecks"

# S2 (docs/audits/2026-08-10-main-bug-audit.md) — `Identity.scalar` and
# `Identity.from` used to read a nested hash with `h[k.to_sym] || h[k]`,
# which drops a genuinely-stored `false` to `nil` (`false || h[k]` falls
# through). A composite/dotted identity part that is itself a boolean
# used to resolve to `nil` and take down the WHOLE identity with it
# (`Identity.of` refuses any part that is `nil`), not merely mis-read
# that one part.
RSpec.describe Hecks::Runtime::Identity do
  describe ".scalar" do
    it "reads a stored false member rather than nil" do
      expect(described_class.scalar("wrapper.active", { active: false })).to be(false)
    end

    it "still reads a stored true member" do
      expect(described_class.scalar("wrapper.active", { active: true })).to be(true)
    end
  end

  describe ".of" do
    # A minimal double is enough: the dotted branch of `.from` never
    # touches `identity_heads`/`.attribute` at all — it walks the raw
    # hash the same way `FieldPath` does.
    IdentityOfFakeConstruct = Struct.new(:identity_paths) unless defined?(IdentityOfFakeConstruct)

    it "resolves a false-valued dotted identity part to its real value, not nil" do
      construct = IdentityOfFakeConstruct.new(["flag.active"])

      expect(described_class.of(construct, { flag: { active: false } })).to eq("false")
    end

    it "still resolves a true-valued dotted identity part" do
      construct = IdentityOfFakeConstruct.new(["flag.active"])

      expect(described_class.of(construct, { flag: { active: true } })).to eq("true")
    end

    it "still refuses (nil) a genuinely absent identity part" do
      construct = IdentityOfFakeConstruct.new(["flag.active"])

      expect(described_class.of(construct, { flag: {} })).to be_nil
    end
  end
end
