require "spec_helper"
require "hecksagain/runtime/reaction_lowering"
require "hecksagain/runtime/reaction_executor"

# PRD 12's own named next step, given a first real instance: does
# `ReactionExecutor` — running a `Reaction` `ReactionLowering.
# lower_process_manager_leg` produces from REAL canonical data — fire
# the SAME dispatch, with the SAME resolved arguments, and produce the
# SAME resulting state a REAL production `SagaInterpreter` leg already
# does? Deliberately scoped to ONE LEG, not a whole chained saga —
# `ReactionExecutor` is not wired into the real event-dispatch loop
# (that wiring is real, separate, future work, named in both this
# executor's own header and PRD 12), so it cannot yet watch for the
# NEXT event a leg's own dispatch emits the way the real `Dispatcher`
# does. What it CAN do, and what this spec proves: given the real
# triggering event and the real correlated state a leg needs, it
# resolves bindings, dispatches, checkpoints at the right boundary, and
# compensates on failure — independently, dispatch by dispatch — the
# same as `SagaInterpreter#deliver_saga_dispatch`/`#unwind` already do.
RSpec.describe Hecksagain::Runtime::ReactionExecutor do
  WIRE_BLUEBOOK = File.join(InMemoryDomain::ROOT, "spec/fixtures/settlement.bluebook")

  def boot_wire
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(WIRE_BLUEBOOK)
    end

    Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
  end

  def fund_drawers(registry)
    registry.dispatch("Wire::Drawer.Open", number: { value: "left" })
    registry.dispatch("Wire::Drawer.Open", number: { value: "right" })
    registry.dispatch("Wire::Drawer.Put",  number: { value: "left" }, amount: { cents: 10_000 })
  end

  # `match_and_checkpoint?` then `dispatch!`, compensating independently
  # on any failed dispatch — the exact two-step, mutex-free shape
  # `SagaInterpreter`'s own real orchestration uses (this test has no
  # mutex to guard, being single-threaded and synchronous, so it skips
  # straight to calling both steps in order). Mirrors this class's own
  # header on why compensation orchestration is a CALLER'S job, not
  # this class's own.
  def run_reaction(executor, reaction, sources:, state:, domain:)
    return { matched: false } unless executor.match_and_checkpoint?(reaction, state: state, sources: sources)

    outcomes = executor.dispatch!(reaction, sources: sources, domain: domain)
    outcomes.each do |outcome|
      next if outcome[:delivered]
      next unless reaction.failure.is_a?(Hecksagain::PrimalIR::Failure::Managed)
      next unless reaction.failure.compensation

      run_reaction(executor, reaction.failure.compensation, sources: sources, state: state, domain: domain)
    end

    { matched: true, outcomes: outcomes }
  end

  let(:process_manager) { registry_b.registry.bluebook("Wire").process_managers.find { |pm| pm.name == "Carry" } }
  let(:handler) { process_manager.handlers.find { |h| h.event_type == "WireAsked" } }
  let(:reaction) { Hecksagain::Runtime::ReactionLowering.lower_process_manager_leg(process_manager, handler) }

  let(:event_payload) do
    { reference: { value: "wire-1" }, amount: { cents: 2_500 }, source: "left", destination: "right" }
  end

  let(:sources) do
    { correlation: { process_manager.correlation_head => "wire-1" }, payload: event_payload, memory: event_payload }
  end

  # `pm.states.first` — the exact state `begin_saga` opens every real
  # instance in, and the leg's own `from_state` this test's handler
  # requires — read off the real process manager rather than hard-coded.
  let(:state) { { state: process_manager.states.first } }

  describe "the success path — matches SagaInterpreter#deliver_saga_dispatch exactly" do
    let(:registry_a) {
      runtime = boot_wire
      fund_drawers(runtime)
      runtime
    }
    let(:registry_b) {
      runtime = boot_wire
      fund_drawers(runtime)
      runtime
    }

    it "resolves the same bindings and dispatches the same command, for the same resulting balance" do
      # PRODUCTION: the real event, dispatched for real — SagaInterpreter's
      # own begin_saga/advance_saga fire the leg through the whole,
      # wired-in pipeline. Captured immediately — `Facade::Surface`'s own
      # global `Wire::Drawer` binding follows whichever registry was
      # BOUND MOST RECENTLY, and `registry_b` (below) rebinds it the
      # moment it's created.
      registry_a.dispatch("Wire::Wire.Ask", reference: { value: "wire-1" }, amount: { cents: 2_500 },
                                            source: "left", destination: "right")
      left_after_production = Wire::Drawer.find("left").cents.to_h

      # EXECUTOR: the SAME leg, lowered and run directly against a
      # SEPARATE, identically-seeded registry — never through the real
      # dispatch pipeline, which never saw "WireAsked" fire on this one.
      door = Hecksagain::Runtime::Dispatcher.new(registry_b.registry)
      outcome = run_reaction(described_class.new(registry_b.registry, door: door), reaction,
                             sources: sources, state: state, domain: "Wire")
      left_after_executor = Wire::Drawer.find("left").cents.to_h

      expect(outcome[:matched]).to be(true)
      expect(outcome[:outcomes]).to all(include(delivered: true))

      # THE SAME EFFECT, both ways — `Drawer::Take` decremented "left"
      # by the same 2,500 cents, resolved through the SAME
      # correlation/payload priority chain `SagaInterpreter#dispatch_args`
      # already uses (`BindingLowering`, shared since the reconciliation).
      expect(left_after_executor).to eq(left_after_production)
      expect(left_after_executor).to eq(cents: 7_500)
    end
  end

  describe "the failure path — compensates independently, matching SagaInterpreter#unwind" do
    let(:registry_b) do
      runtime = boot_wire
      fund_drawers(runtime)
      runtime.dispatch("Wire::Drawer.Shut", number: { value: "right" })
      runtime
    end

    # The SECOND leg ("carrying" — the credit into "right"), not the
    # first — this is the one that actually refuses (a shut drawer)
    # and needs compensating (`unwind`'s own real scenario, mirrored
    # from `spec/runtime/saga_spec.rb`'s "unwinds a refused leg on its
    # own" test).
    let(:credit_handler) { process_manager.handlers.find { |h| h.event_type == "Taken" } }
    let(:credit_reaction) { Hecksagain::Runtime::ReactionLowering.lower_process_manager_leg(process_manager, credit_handler) }
    let(:credit_state) { { state: credit_handler.from_state } }
    let(:credit_sources) do
      { correlation: { process_manager.correlation_head => "wire-1" }, payload: event_payload, memory: event_payload }
    end

    it "fires the compensating leg on refusal, crediting the source drawer back" do
      door = Hecksagain::Runtime::Dispatcher.new(registry_b.registry)
      outcome = run_reaction(described_class.new(registry_b.registry, door: door), credit_reaction,
                             sources: credit_sources, state: credit_state, domain: "Wire")

      expect(outcome[:matched]).to be(true)
      # The credit leg's OWN "Drawer::Put" into "right" refuses (shut) —
      # recorded, not raised.
      expect(outcome[:outcomes]).to include(a_hash_including(delivered: false))

      # Compensation ran too: the money that left "left" in an earlier,
      # separate leg is not this test's own concern (this test starts
      # already at "carrying", the credit leg's own `from_state`) — what
      # IS this test's concern is that the compensating leg's own
      # dispatch (`Drawer::Put` back into "left") fired for real.
      expect(Wire::Drawer.find("left").cents.to_h).to eq(cents: 12_500)
    end
  end
end
