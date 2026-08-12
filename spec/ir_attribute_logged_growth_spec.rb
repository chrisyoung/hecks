require "spec_helper"

# Real coverage for IR::Attribute#logged: a command argument (old_string,
# in particular) that should never round-trip into an audit log verbatim.
# Structural-only at this point in the split -- captured on the IR so the
# corpus boots, NOT YET consulted by whatever writes the audit log (a
# documented, deliberate gap matching this session's other structural-only
# additions), and NOT yet on `#to_h` (the wire) for the same reason.
#
# The DSL surface itself (`attribute :x, T, logged: false`) is bundled,
# in the real source, inside attribute_collector.rb's own much larger
# rewrite alongside `as:`'s inverted-form resolution, `required:`, and
# `enum:` (1855be0, this split's own 1855be0-b/1855be0-c territory) --
# untangling that bundle is deliberately deferred rather than pulled
# forward here, since `logged` itself is safe, isolated, and has no
# functional consumer yet either way. This spec exercises IR::Attribute
# directly instead of through a real bluebook dispatch.
RSpec.describe "IR::Attribute#logged" do
  def build_attribute(**overrides)
    Hecksagain::Bluebook::IR::Attribute.new(name: :old_string, type: "OldString", **overrides)
  end

  it "defaults to true -- logged unless told otherwise" do
    attribute = build_attribute

    expect(attribute.logged).to be(true)
  end

  it "captures logged: false" do
    attribute = build_attribute(logged: false)

    expect(attribute.logged).to be(false)
  end

  it "does not (yet) appear on #to_h -- structural-only, not on the wire" do
    attribute = build_attribute(logged: false)

    expect(attribute.to_h).not_to have_key(:logged)
  end
end
