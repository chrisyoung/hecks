require "spec_helper"
require "hecksagain/runtime/reaction_lowering"

# PRD 12 (ADR 0030 Slice 3, design) — a first, small, honest instance of
# the ADR's own acceptance test for `Reaction`: "take the lowered
# executable IR, erase every trace of which canonical construct it came
# from, and run it. If the runtime still reproduces exactly the correct
# behaviour, the decomposition succeeded." This spec proves the SHAPE
# survives provenance erasure, against REAL canonical data (a real
# `policy` and a real `process_manager` leg, off the actual loaded
# banking domain) — it does NOT prove the full criterion, which needs a
# real `Reaction` executor that doesn't exist yet (PRD 12's own "What's
# proven, and what isn't").
RSpec.describe "Reaction survives provenance erasure" do
  BANKING_BLUEBOOK = File.join(InMemoryDomain::ROOT, "examples/banking/bluebook/banking.bluebook")

  def boot_banking
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(BANKING_BLUEBOOK)
    end

    registry
  end

  let(:registry) { boot_banking }
  let(:banking)  { registry.bluebook("Banking") }

  # A REAL policy — "NotifyOnClosure": unconditional (`where` empty),
  # no `with_spec` — the plain, ordinary single-dispatch case.
  let(:policy) { banking.policies.find { |p| p.name == "NotifyOnClosure" } }

  # A REAL policy that DOES declare `with_spec` — banking's only one
  # (`FreezeAccountsOnSuspension`, also a `for_each` fan-out; the fan-out
  # itself is out of scope for this minimal lowering — only its
  # `with_spec`'s own real resolution shape is exercised here).
  let(:policy_with_bindings) { banking.policies.find { |p| p.name == "FreezeAccountsOnSuspension" } }

  # A REAL process-manager leg — "Settlement"'s own first transition.
  let(:process_manager) { banking.process_managers.find { |pm| pm.name == "Settlement" } }
  let(:handler) { process_manager.handlers.first }

  it "finds the real fixtures this spec depends on" do
    expect(policy).not_to be_nil
    expect(process_manager).not_to be_nil
    expect(handler).not_to be_nil
  end

  # ADR 0030's own Question 6 (canonical-only omission), checked
  # mechanically, not just asserted in prose: `Reaction` never had a
  # `goal`/`description` slot to begin with — not because this PRD
  # chose to drop one, but because `PolicyInterpreter`/`SagaInterpreter`,
  # read line by line during the ADR 0029 extraction, never once
  # referenced `.goal`/`.description` at all. An executable form that
  # omits them was never at risk of losing real behaviour.
  it "carries no canonical-only documentation field — Question 6, checked" do
    expect(Hecksagain::Runtime::ReactionLowering::Reaction.members).not_to include(:goal, :description)
  end

  it "lowers both into instances of the SAME Ruby class" do
    from_policy = Hecksagain::Runtime::ReactionLowering.lower_policy(policy)
    from_leg    = Hecksagain::Runtime::ReactionLowering.lower_process_manager_leg(process_manager, handler)

    expect(from_policy).to be_a(Hecksagain::Runtime::ReactionLowering::Reaction)
    expect(from_leg).to be_a(Hecksagain::Runtime::ReactionLowering::Reaction)
    expect(from_policy.class).to eq(from_leg.class)
  end

  it "carries no field naming which canonical construct produced it — only VALUES distinguish them" do
    from_policy = Hecksagain::Runtime::ReactionLowering.lower_policy(policy)
    from_leg    = Hecksagain::Runtime::ReactionLowering.lower_process_manager_leg(process_manager, handler)

    # `Reaction`'s own declared members — no `origin`/`kind`/`source_type`
    # field anywhere in the struct itself, checked mechanically rather
    # than by inspection alone.
    expect(Hecksagain::Runtime::ReactionLowering::Reaction.members).not_to include(:origin, :kind, :source_type, :canonical_type)

    # The two really do differ — by real, named capability (context/
    # persistence/failure), not by an origin tag standing in for one.
    expect(from_policy.context).to be_a(Hecksagain::Runtime::ReactionLowering::Context::Stateless)
    expect(from_leg.context).to be_a(Hecksagain::Runtime::ReactionLowering::Context::Correlated)
    expect(from_policy.persistence).to be_a(Hecksagain::Runtime::ReactionLowering::Persistence::Ephemeral)
    expect(from_leg.persistence).to be_a(Hecksagain::Runtime::ReactionLowering::Persistence::Checkpointed)
    expect(from_policy.failure).to be_a(Hecksagain::Runtime::ReactionLowering::Failure::Drop)
    expect(from_leg.failure).to be_a(Hecksagain::Runtime::ReactionLowering::Failure::Managed)
  end

  it "evaluates BOTH conditions through the exact same function, with no branch on origin" do
    from_policy = Hecksagain::Runtime::ReactionLowering.lower_policy(policy)
    from_leg    = Hecksagain::Runtime::ReactionLowering.lower_process_manager_leg(process_manager, handler)

    # The policy's own `where` is empty (NotifyOnClosure fires
    # unconditionally) — `condition: nil`, evaluated as unconditionally
    # true by `evaluate_condition` itself, not by a caller-side check.
    expect(from_policy.condition).to be_nil
    expect(Hecksagain::Runtime::ReactionLowering.evaluate_condition(from_policy, {}, {})).to be(true)

    # The leg's own guard is real, generated `Expr::Compare` — true when
    # `state` matches the leg's own `from_state`, false otherwise. `state`
    # is looked up as a bare `Lookup`, same as `Evaluator`'s own state
    # argument for a command's given/ensures.
    matching_state     = { state: handler.from_state }
    non_matching_state = { state: "#{handler.from_state}-not-it" }

    expect(Hecksagain::Runtime::ReactionLowering.evaluate_condition(from_leg, matching_state, {})).to be(true)
    expect(Hecksagain::Runtime::ReactionLowering.evaluate_condition(from_leg, non_matching_state, {})).to be(false)
  end

  it "walks the mechanical-criterion table's own 'same stage, different strategy' claim for bindings" do
    # `Reaction.dispatches[*].bindings` for both is the SAME node type
    # (`BindingLowering::ExecutableBinding`) — a real `with_spec` entry
    # on each, resolved through the one shared `BindingLowering.resolve`,
    # never a policy-shaped resolver and a saga-shaped one.
    from_policy = Hecksagain::Runtime::ReactionLowering.lower_policy(policy_with_bindings)
    from_leg    = Hecksagain::Runtime::ReactionLowering.lower_process_manager_leg(process_manager, handler)

    policy_bindings = from_policy.dispatches.flat_map(&:bindings)
    leg_bindings = from_leg.dispatches.flat_map(&:bindings)

    expect(policy_bindings).not_to be_empty
    expect(leg_bindings).not_to be_empty
    expect(policy_bindings + leg_bindings).to all(be_a(Hecksagain::Bluebook::Expression::BindingLowering::ExecutableBinding))
  end
end
