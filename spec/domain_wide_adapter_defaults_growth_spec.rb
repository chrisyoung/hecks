require "spec_helper"
require "tempfile"

# Real coverage for HecksagonBuilder's domain-wide persisted_by defaults:
# a bare `adapter :heki` / `adapter :memory` / `adapter :sqlite` (no
# aggregate qualifier, no block) inside a hecksagon means "every
# aggregate in this bluebook persists here unless overridden" -- the
# exact shape the canonical pizzas example's own sqlite context uses,
# with its own documented precedence rule: an aggregate-level
# `persisted_by(...)` bind, wherever it appears in the file, wins.
#
# Applied at #build time (once every explicit bind in the SAME
# hecksagon file is known), not the moment `adapter :kind` is
# evaluated -- resolving it immediately would see an empty @binds and
# synthesize a bind for an aggregate whose own explicit override
# appears LATER in the same file, colliding with it.
RSpec.describe "HecksagonBuilder domain-wide adapter defaults" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["domain-wide-adapter-defaults-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  DOMAIN_WIDE_ADAPTER_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "DomainWideAdapterGrowth" do
      aggregate "Lamp" do
        identified_by { lamp_id.value }

        value_object "LampId" do
          attribute :value, String
        end

        attribute :lamp_id, LampId

        command "TurnOn" do
          attribute :lamp_id, LampId
          emits "LampTurnedOn"
        end
      end

      aggregate "Fuse" do
        identified_by { fuse_id.value }

        value_object "FuseId" do
          attribute :value, String
        end

        attribute :fuse_id, FuseId

        command "Blow" do
          attribute :fuse_id, FuseId
          emits "FuseBlown"
        end
      end
    end
  BLUEBOOK

  def repository_for(runtime, aggregate_name)
    bluebook = runtime.registry.bluebook("DomainWideAdapterGrowth")
    aggregate = bluebook.aggregate(aggregate_name)
    runtime.registry.repository("DomainWideAdapterGrowth", aggregate)
  end

  it "binds every aggregate to the domain-wide default when nothing overrides it" do
    runtime = boot(DOMAIN_WIDE_ADAPTER_SOURCE, "DomainWideAdapterGrowth") do
      adapter :memory
    end

    expect { runtime.dispatch("DomainWideAdapterGrowth::Lamp.TurnOn", lamp_id: { value: "lamp-1" }) }
      .not_to raise_error
    expect { runtime.dispatch("DomainWideAdapterGrowth::Fuse.Blow", fuse_id: { value: "fuse-1" }) }
      .not_to raise_error
  end

  it "an explicit aggregate-level persisted_by bind, declared AFTER the domain-wide default, still wins" do
    runtime = boot(DOMAIN_WIDE_ADAPTER_SOURCE, "DomainWideAdapterGrowth") do
      adapter :memory
      ::DomainWideAdapterGrowth::Fuse.persisted_by("Memory")
    end

    bluebook_ir = runtime.registry.bluebook("DomainWideAdapterGrowth")
    hecksagon_ir = runtime.registry.hecksagon("DomainWideAdapterGrowth")

    fuse_binds = hecksagon_ir.binds.select { |b| b.aggregate_name == "Fuse" && b.verb == "persisted_by" }
    expect(fuse_binds.size).to eq(1), "the explicit bind must not be duplicated by the domain-wide default"

    lamp_binds = hecksagon_ir.binds.select { |b| b.aggregate_name == "Lamp" && b.verb == "persisted_by" }
    expect(lamp_binds.size).to eq(1), "Lamp has no explicit bind, so the domain-wide default must supply one"
    expect(lamp_binds.first.adapter).to eq("Memory")

    expect(bluebook_ir).not_to be_nil
  end

  it "records nothing extra when the hecksagon declares no domain-wide adapter at all" do
    runtime = boot(DOMAIN_WIDE_ADAPTER_SOURCE, "DomainWideAdapterGrowth") do
      ::DomainWideAdapterGrowth::Lamp.persisted_by("Memory")
      ::DomainWideAdapterGrowth::Fuse.persisted_by("Memory")
    end

    hecksagon_ir = runtime.registry.hecksagon("DomainWideAdapterGrowth")
    expect(hecksagon_ir.binds.size).to eq(2)
  end
end
