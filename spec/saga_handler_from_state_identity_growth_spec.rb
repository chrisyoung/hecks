require "spec_helper"
require "tempfile"

# Real coverage for the self-hosted grammar identity fix on `Handler`:
# `identified_by { process_manager_id; event_type.value }` alone collapses
# two legs answering the SAME event from two DIFFERENT states into one
# meta-domain identity. Before `from_state.value` joined the identity, the
# self-hosted grammar's own Judge crashed with `AlreadyExists` the moment a
# process manager declared a second leg for an event it already answered
# from a different state -- a legitimate, common shape (a state machine
# answering the same event differently depending on where it currently is).
RSpec.describe "saga Handler identity includes from_state" do
  HANDLER_IDENTITY_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "HandlerIdentityGrowth" do
      aggregate "Widget" do
        identified_by { id.value }
        value_object "WidgetId" do
          attribute :value, String
        end
        attribute :id, WidgetId

        command "Open" do
          attribute :id, WidgetId
          emits "Opened"
        end
        command "Foo" do
          reference_to Widget
          emits "Fooed"
        end
        command "Bar" do
          reference_to Widget
          emits "Barred"
        end
      end

      process_manager "TwoLegSaga" do
        correlates_by :"id.value"
        starts_on "Opened"
        ends_on "Barred"

        state "a"
        state "b"
        state "c"

        # SAME EVENT, TWO DIFFERENT from_states -- the exact shape that
        # collided into one identity before this fix.
        on "Ping", transition: { "a" => "b" } do
          dispatch "HandlerIdentityGrowth::Widget.Foo", with: { id: :id }
        end

        on "Ping", transition: { "b" => "c" } do
          dispatch "HandlerIdentityGrowth::Widget.Bar", with: { id: :id }
        end
      end
    end
  BLUEBOOK

  def judged_handler_identity_growth
    file = Tempfile.new(["handler-identity-growth-", ".bluebook"])
    file.write(HANDLER_IDENTITY_SOURCE)
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
      bluebook = Kernel.eval(HANDLER_IDENTITY_SOURCE, TOPLEVEL_BINDING, file.path, 1)
    end

    judge = Hecksagain::Bluebook::MetaValidator::Judge.new(bluebook)
    [judge, Hecksagain::Bluebook::MetaValidator::Reconstruction.of(judge.runtime, bluebook.hecks_name)]
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  it "judges both legs without raising AlreadyExists" do
    expect { judged_handler_identity_growth }.not_to raise_error
  end

  it "keeps both legs as distinct handler records" do
    judge, reconstruction = judged_handler_identity_growth

    expect(judge.refusals).to be_empty

    process_manager = reconstruction[:process_managers].find { |pm| pm[:name] == "TwoLegSaga" }
    expect(process_manager[:handlers].size).to eq(2)

    legs = process_manager[:handlers].map { |h| h.values_at(:event_type, :from_state, :to_state) }
    expect(legs).to contain_exactly(
      %w[Ping a b],
      %w[Ping b c]
    )
  end
end
