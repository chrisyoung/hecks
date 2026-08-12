require "spec_helper"
require "tempfile"

# Real coverage for the self-hosted grammar identity fix on `Dispatch`:
# `identified_by { handler_id; command_name.value }` alone collapses two
# dispatches of the SAME command, with different `with:` bindings, inside
# one handler into one meta-domain identity -- a real, legitimate fan-out
# pattern (one handler sending the same command several times, once per
# argument set). Before `position.value` joined the identity, the
# self-hosted grammar's own Judge crashed with `AlreadyExists` the instant
# a handler dispatched the same command name twice.
RSpec.describe "saga Dispatch identity includes position" do
  DISPATCH_IDENTITY_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "DispatchIdentityGrowth" do
      aggregate "Organ" do
        identified_by { id.value }
        value_object "OrganId" do
          attribute :value, String
        end
        attribute :id, OrganId

        command "Open" do
          attribute :id, OrganId
          emits "Opened"
        end
        command "Fire" do
          reference_to Organ
          attribute :label, OrganId
          emits "Fired"
        end
      end

      process_manager "FanOutSaga" do
        correlates_by :"id.value"
        starts_on "Opened"
        ends_on "Fired"

        state "opening"
        state "opened"

        # ONE HANDLER, THE SAME COMMAND DISPATCHED TWICE with different
        # with: bindings -- the exact shape that collided into one
        # identity before this fix.
        on "Opened", transition: { "opening" => "opened" } do
          dispatch "DispatchIdentityGrowth::Organ.Fire", with: { id: :id, label: :id }
          dispatch "DispatchIdentityGrowth::Organ.Fire", with: { id: :id, label: :id }
        end
      end
    end
  BLUEBOOK

  def judged_dispatch_identity_growth
    file = Tempfile.new(["dispatch-identity-growth-", ".bluebook"])
    file.write(DISPATCH_IDENTITY_SOURCE)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    bluebook = nil
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      bluebook = Kernel.eval(DISPATCH_IDENTITY_SOURCE, TOPLEVEL_BINDING, file.path, 1)
    end

    judge = Hecksagain::Bluebook::MetaValidator::Judge.new(bluebook)
    [judge, Hecksagain::Bluebook::MetaValidator::Reconstruction.of(judge.runtime, bluebook.hecks_name)]
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  it "judges both dispatches without raising AlreadyExists" do
    expect { judged_dispatch_identity_growth }.not_to raise_error
  end

  it "keeps both same-command dispatches as distinct records, in declared order" do
    judge, reconstruction = judged_dispatch_identity_growth

    expect(judge.refusals).to be_empty

    process_manager = reconstruction[:process_managers].find { |pm| pm[:name] == "FanOutSaga" }
    handler = process_manager[:handlers].first

    expect(handler[:dispatches].size).to eq(2)
    expect(handler[:dispatches].map { |d| d[:command_name] }).to eq(
      ["DispatchIdentityGrowth::Organ.Fire", "DispatchIdentityGrowth::Organ.Fire"]
    )
  end
end
