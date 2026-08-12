require "spec_helper"

# Real coverage for Registry#add_hecksagon's multi-file accumulation fix:
# before this, add_hecksagon was a plain hash overwrite, the same gap
# add_bluebook already solves for multi-file bluebooks but never extended to
# hecksagons. A domain's .hecksagon binds routinely split one-file-per-
# aggregate (conductor/{merge_queue,lease,sweeper,claim,worker}.hecksagon,
# all `Hecks.hecksagon "Conductor"`) -- each Declare built a fresh
# IR::Hecksagon and overwrote the one before, so only the LAST-loaded
# file's binds survived registry-wide. Now merges binds/subscriptions/
# framework_members/driving_handlers across every call for the same domain.
RSpec.describe "Registry#add_hecksagon merges multi-file hecksagon declarations" do
  def bind_for(aggregate)
    Hecksagain::Bluebook::IR::Bind.new(aggregate: aggregate, verb: "persisted_by", adapter: "Memory", role: nil)
  end

  def hecksagon_for(domain, *binds)
    Hecksagain::Bluebook::IR::Hecksagon.new(domain: domain, binds: binds)
  end

  it "merges a second file's binds into the first, rather than overwriting them" do
    registry = Hecksagain::Runtime::Registry.new

    registry.add_hecksagon(hecksagon_for("Conductor", bind_for("Conductor::MergeQueue")))
    registry.add_hecksagon(hecksagon_for("Conductor", bind_for("Conductor::Lease")))
    registry.add_hecksagon(hecksagon_for("Conductor", bind_for("Conductor::Sweeper")))

    merged = registry.hecksagons["Conductor"]
    expect(merged.binds.map(&:aggregate_name)).to contain_exactly("MergeQueue", "Lease", "Sweeper")

    # the whole point: the FIRST file's own bind must still be resolvable
    # after later files load, not just the last one
    expect(merged.bind_for("MergeQueue", "persisted_by")).not_to be_nil
  end

  it "merges subscriptions, framework_members, and driving_handlers too" do
    registry = Hecksagain::Runtime::Registry.new

    first = Hecksagain::Bluebook::IR::Hecksagon.new(
      domain: "Conductor", binds: [], subscriptions: ["Sub1"], framework_members: ["Fw1"], driving_handlers: []
    )
    second = Hecksagain::Bluebook::IR::Hecksagon.new(
      domain: "Conductor", binds: [], subscriptions: ["Sub2"], framework_members: [], driving_handlers: ["Dh1"]
    )

    registry.add_hecksagon(first)
    registry.add_hecksagon(second)

    merged = registry.hecksagons["Conductor"]
    expect(merged.subscriptions).to eq(%w[Sub1 Sub2])
    expect(merged.framework_members).to eq(%w[Fw1])
    expect(merged.driving_handlers).to eq(%w[Dh1])
  end

  it "does not merge across different domains" do
    registry = Hecksagain::Runtime::Registry.new

    registry.add_hecksagon(hecksagon_for("Conductor", bind_for("Conductor::MergeQueue")))
    registry.add_hecksagon(hecksagon_for("OtherDomain", bind_for("OtherDomain::Thing")))

    expect(registry.hecksagons["Conductor"].binds.map(&:aggregate_name)).to eq(["MergeQueue"])
    expect(registry.hecksagons["OtherDomain"].binds.map(&:aggregate_name)).to eq(["Thing"])
  end
end
