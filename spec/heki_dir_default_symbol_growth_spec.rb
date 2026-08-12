require "spec_helper"
require "tmpdir"

# Real coverage for Heki#resolve_path's dir: :default fix: a bare Symbol
# `dir: :default` setting -- hecks_conception/miette's own convention for
# "a declared value that resolves by convention, never a silent
# fallback" -- crashed File.join outright (TypeError: no implicit
# conversion of Symbol into String), because resolve_path only ever
# checked for a MISSING setting, never a Symbol one. Treated the same as
# no setting at all now, falling back to the existing "data" default.
RSpec.describe "Heki#resolve_path with a bare Symbol dir: :default setting" do
  let(:aggregate) do
    boot_in_memory.registry.bluebook("Pizzas").aggregate("Order")
  end

  it "falls back to the 'data' default instead of crashing on a Symbol" do
    Dir.mktmpdir do |root|
      adapter = Hecksagain::Adapters::Heki.new(aggregate: aggregate, settings: { dir: :default }, root: root)

      expect(adapter.path).to eq(File.join(root, "data", "order.heki"))
    end
  end

  it "still honors a real declared string path" do
    Dir.mktmpdir do |root|
      adapter = Hecksagain::Adapters::Heki.new(aggregate: aggregate, settings: { dir: "custom" }, root: root)

      expect(adapter.path).to eq(File.join(root, "custom", "order.heki"))
    end
  end

  it "still falls back to 'data' when no dir setting is given at all" do
    Dir.mktmpdir do |root|
      adapter = Hecksagain::Adapters::Heki.new(aggregate: aggregate, settings: {}, root: root)

      expect(adapter.path).to eq(File.join(root, "data", "order.heki"))
    end
  end
end
