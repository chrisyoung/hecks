require "spec_helper"

# Real coverage for IR::World::Binding#for_binding's generic-settings
# fallback fix: the bare fallback used to be
# `@settings.fetch("verb:adapter", for_verb(verb))` unconditionally --
# but `for_verb(verb)` is whichever adapter's bare top-level block was
# declared LAST, and falling back to it for an UNRELATED adapter applies
# one adapter's settings to another's bind. Real, corpus-caught bug:
# deciderate.hecksagon binds Game/Vote to Heki and Bubble to Memory ; the
# world configures only Heki's `dir`, and Bubble's lookup for
# "persisted_by:memory" fell back to Heki's own settings, then failed
# check_settings with "Memory does not declare :dir".
RSpec.describe "IR::World::Binding#for_binding generic-settings fallback" do
  # unit-level, direct construction: the WorldBuilder DSL always writes
  # BOTH the bare-verb key and the qualified verb:adapter key together
  # (record_binding's own shared write path) for whichever adapter it
  # names, so a generic-only settings hash (no qualified key at all) is
  # the exact shape #for_binding must still handle correctly.
  def world_with_generic_only(verb, adapter, extra = {})
    Hecksagain::Bluebook::IR::World.new(
      domain: "DeciderateGrowth",
      settings: { verb.to_s => { adapter: adapter }.merge(extra) }
    )
  end

  it "does not leak one adapter's generic settings onto an unrelated adapter's lookup" do
    world = world_with_generic_only("persisted_by", "Heki", dir: "custom")

    # Memory was never configured -- the bug applied Heki's `dir`
    # setting to it anyway
    expect(world.for_binding("persisted_by", "Memory")).to eq({})
  end

  it "still honors the generic fallback when the adapter genuinely matches" do
    world = world_with_generic_only("persisted_by", "Heki", dir: "custom")

    expect(world.for_binding("persisted_by", "Heki")).to eq(adapter: "Heki", dir: "custom")
  end

  it "a qualified verb:adapter entry still wins outright, without consulting the generic one" do
    world = Hecksagain::Bluebook::IR::World.new(
      domain: "DeciderateGrowth",
      settings: {
        "persisted_by"       => { adapter: "Heki", dir: "generic-dir" },
        "persisted_by:heki"  => { adapter: "Heki", dir: "qualified-dir" }
      }
    )

    expect(world.for_binding("persisted_by", "Heki")).to eq(adapter: "Heki", dir: "qualified-dir")
  end
end
