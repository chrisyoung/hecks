require "spec_helper"

# THE QA LEDGER, EXERCISED THE WAY IT WILL ACTUALLY BE USED.
#
# Booted against Memory rather than against `qa/bluebook/quality_control.hecksagon`'s
# own Heki binding — a spec that wrote to `qa/data/` would leave the real
# ledger different after every run, which is the one thing a durable store
# must not do to its own test. Only the WIRING is swapped; the chapter under
# test is the same file the tool boots.
RSpec.describe "QualityControl" do
  QC_BLUEBOOK = File.join(InMemoryDomain::ROOT, "qa/bluebook/quality_control.bluebook").freeze

  def boot_quality_control
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      # The extraction port — `identified_by` recovers its own predicate's
      # source through it, so a boot without it refuses at the first
      # aggregate rather than at dispatch.
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(QC_BLUEBOOK)

      Hecks.hecksagon("QualityControl") do
        ::QualityControl::Session.persisted_by("Memory")
        ::QualityControl::Bug.persisted_by("Memory")
        ::QualityControl::Remedy.persisted_by("Memory")
        ::QualityControl::Ticket.persisted_by("Memory")
      end
    end

    registry.verify!
    Hecksagain::Runtime::Dispatcher.new(registry)
  end

  subject(:qc) { boot_quality_control }

  # The shape every example starts from: a live session with one failing
  # test case in it, which is the only honest way a bug comes into being.
  def session_with_failing_test(reference: "QA-2026-08-11")
    qc.dispatch("QualityControl::Session.Start",
                reference: { value: reference },
                engineer: { value: "Claude QA" })
    qc.dispatch("QualityControl::Session.Test",
                id: reference,
                domain: { value: "Pizzas" },
                category: { value: "empty" },
                subject: { value: "Pizzas::Order.CreatePizza" },
                expectation: { value: "a whitespace-only pizza name is refused" },
                location: { value: 'spec/qa_bugs_spec.rb -e "BUG#4"' })
    qc.dispatch("QualityControl::Session.TestCase.Fail",
                id: reference, sequence: { value: 1 },
                observation: { value: "the command succeeded and stored '   '" })
    reference
  end

  def discover_bug(session, reference: "BUG#4", severity: "medium")
    qc.dispatch("QualityControl::Bug.Discover",
                session_id: session,
                reference: { value: reference },
                sequence: { value: 4 },
                domain: { value: "Pizzas" },
                title: { value: "Whitespace-only strings accepted as names" },
                symptom: { value: "PizzaName '   ' is stored verbatim" },
                expectation: { value: "an InvariantViolation, as for the empty string" },
                severity: { value: severity })
    reference
  end

  describe "the session" do
    it "numbers its own test cases and counts them" do
      session = session_with_failing_test

      handle = qc.dispatch("QualityControl::Session.Test",
                           id: session,
                           domain: { value: "Pizzas" },
                           category: { value: "boundary" },
                           subject: { value: "Pizzas::Order.CreatePizza" },
                           expectation: { value: "a zero price is refused" },
                           location: { value: 'spec/qa_bugs_spec.rb -e "BUG#2"' })

      expect(handle.state[:tested][:value]).to eq(2)
      expect(handle.state[:test_cases].map { |t| t[:sequence][:value] }).to eq([1, 2])
    end

    it "refuses to complete a session that tested nothing" do
      qc.dispatch("QualityControl::Session.Start",
                  reference: { value: "QA-EMPTY" }, engineer: { value: "Claude QA" })

      expect {
        qc.dispatch("QualityControl::Session.Complete", id: "QA-EMPTY",
                    notes: { value: "Nothing was run, but here are forty characters of notes." })
      }.to raise_error(Hecksagain::Runtime::GivenNotMet, /tested nothing/)
    end

    it "refuses a session note too short to be a finding" do
      session = session_with_failing_test

      expect {
        qc.dispatch("QualityControl::Session.Complete", id: session, notes: { value: "done" })
      }.to raise_error(Hecksagain::Runtime::InvariantViolation, /what it learned/)
    end

    it "refuses to write a test case into a paused session" do
      session = session_with_failing_test
      qc.dispatch("QualityControl::Session.Pause", id: session)

      expect {
        qc.dispatch("QualityControl::Session.Test", id: session,
                    domain: { value: "Pizzas" }, category: { value: "state" },
                    subject: { value: "Pizzas::Order.Purchase" },
                    expectation: { value: "a double purchase is refused" },
                    location: { value: "spec/pizzas_spec.rb" })
      }.to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "paused"/)
    end
  end

  # THE GATE THE WHOLE CHAPTER STANDS ON, and it costs no predicate: the
  # machine simply has no edge out of `found` except `Reproduce`, so the
  # refusal is `LifecycleRefused` naming the states it would have moved
  # from. Asserted on the wording as well as the class — that sentence is
  # what a QA agent reads when the tool says no.
  describe "the reproduce gate" do
    it "refuses to investigate a bug nobody has reproduced" do
      bug = discover_bug(session_with_failing_test)

      expect {
        qc.dispatch("QualityControl::Bug.Investigate", id: bug,
                    site: { value: "examples/pizzas/bluebook/pizzas.bluebook" },
                    cause: { value: "the invariant does not strip before checking emptiness" })
      }.to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "reproduced"/)
    end

    it "refuses to dismiss a bug nobody has reproduced" do
      bug = discover_bug(session_with_failing_test)

      expect {
        qc.dispatch("QualityControl::Bug.Dismiss", id: bug,
                    reason: { value: "probably correct behaviour" })
      }.to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "found"/)
    end

    it "lists it as unreproduced until a demonstration exists" do
      bug = discover_bug(session_with_failing_test)

      expect(qc.query("QualityControl::Bug.Unreproduced").map { |r| r[:reference][:value] }).to eq([bug])

      qc.dispatch("QualityControl::Bug.Reproduce", id: bug,
                  demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#4"' })

      expect(qc.query("QualityControl::Bug.Unreproduced")).to be_empty
    end
  end

  describe "the commit rule" do
    def bug_ready_to_fix
      bug = discover_bug(session_with_failing_test)
      qc.dispatch("QualityControl::Bug.Reproduce", id: bug,
                  demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#4"' })
      qc.dispatch("QualityControl::Bug.Investigate", id: bug,
                  site: { value: "examples/pizzas/bluebook/pizzas.bluebook" },
                  cause: { value: "the invariant does not strip before checking emptiness" })
      bug
    end

    it "cannot mark a bug fixed without a commit at all" do
      expect { qc.dispatch("QualityControl::Bug.Fix", id: bug_ready_to_fix) }
        .to raise_error(Hecksagain::Runtime::AbsentArgument)
    end

    it "refuses a commit that is not a sha" do
      expect {
        qc.dispatch("QualityControl::Bug.Fix", id: bug_ready_to_fix, commit: { value: "later" })
      }.to raise_error(Hecksagain::Runtime::TypeMismatch, /must match/)
    end

    it "takes a real sha and only then allows verification" do
      bug = bug_ready_to_fix
      qc.dispatch("QualityControl::Bug.Fix", id: bug, commit: { value: "63750a3" })

      expect(qc.query("QualityControl::Bug.ReadyToVerify").map { |r| r[:reference][:value] }).to eq([bug])

      handle = qc.dispatch("QualityControl::Bug.Verify", id: bug)
      expect(handle.state[:status]).to eq("verified")
    end

    it "cannot verify a bug that was never fixed" do
      expect { qc.dispatch("QualityControl::Bug.Verify", id: bug_ready_to_fix) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "fixed"/)
    end
  end

  describe "fix first, file second" do
    def paused_bug
      bug = discover_bug(session_with_failing_test, reference: "BUG#2", severity: "high")
      qc.dispatch("QualityControl::Bug.Reproduce", id: bug,
                  demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#2"' })
      qc.dispatch("QualityControl::Bug.Investigate", id: bug,
                  site: { value: "lib/hecksagain/runtime/value/coercion.rb" },
                  cause: { value: "Value::Coercion.build does not recurse into nested value objects" })
      bug
    end

    it "refuses to draft a ticket that cannot name an attempt" do
      bug = paused_bug

      expect {
        qc.dispatch("QualityControl::Ticket.Draft",
                    bug_id: bug, remedy_id: "REM-nope",
                    reference: { value: "TK-1" },
                    repository: { value: "chrisyoung/hecksagain" },
                    title: { value: "Nested value object invariants are not validated" },
                    body: { value: "..." })
      }.to raise_error(Hecksagain::Runtime::NotFound)
    end

    it "drafts once an attempt has been abandoned, and carries its reason" do
      bug = paused_bug
      qc.dispatch("QualityControl::Remedy.Attempt", bug_id: bug,
                  reference: { value: "REM-1" }, sequence: { value: 1 },
                  engineer: { value: "Claude QA" },
                  approach: { value: "recurse in Value::Coercion.build over nested value objects" })
      qc.dispatch("QualityControl::Remedy.Touch", id: "REM-1",
                  path: { value: "lib/hecksagain/runtime/value/coercion.rb" },
                  note: { value: "tried a recursive build; broke era reconstruction" })
      abandoned = qc.dispatch("QualityControl::Remedy.Abandon", id: "REM-1",
                              reason: { value: "requires a refactor of the whole coercion pipeline" })

      expect(abandoned.state[:changes].length).to eq(1)

      qc.dispatch("QualityControl::Bug.Pause", id: bug,
                  reason: { value: abandoned.state[:reason][:value] })

      expect {
        qc.dispatch("QualityControl::Ticket.Draft",
                    bug_id: bug, remedy_id: "REM-1",
                    reference: { value: "TK-1" },
                    repository: { value: "chrisyoung/hecksagain" },
                    title: { value: "Nested value object invariants are not validated" },
                    body: { value: "Why not fixed: requires a refactor of the coercion pipeline." })
      }.not_to raise_error

      expect(qc.query("QualityControl::Bug.Paused").map { |r| r[:reference][:value] }).to eq([bug])
    end

    it "surfaces a ticket drafted while its attempt is still live" do
      bug = paused_bug
      qc.dispatch("QualityControl::Remedy.Attempt", bug_id: bug,
                  reference: { value: "REM-1" }, sequence: { value: 1 },
                  engineer: { value: "Claude QA" },
                  approach: { value: "recurse in Value::Coercion.build" })
      qc.dispatch("QualityControl::Ticket.Draft",
                  bug_id: bug, remedy_id: "REM-1",
                  reference: { value: "TK-1" },
                  repository: { value: "chrisyoung/hecksagain" },
                  title: { value: "Nested VO invariants" }, body: { value: "..." })

      expect(qc.query("QualityControl::Ticket.RestingOnLiveRemedy").map { |r| r[:reference][:value] })
        .to eq(["TK-1"])
      expect(qc.query("QualityControl::Remedy.Unresolved").map { |r| r[:reference][:value] })
        .to eq(["REM-1"])
    end
  end

  describe "the tracker is somebody else's database" do
    def drafted_ticket
      bug = discover_bug(session_with_failing_test, reference: "BUG#2", severity: "high")
      qc.dispatch("QualityControl::Bug.Reproduce", id: bug, demonstration: { value: "rspec ..." })
      qc.dispatch("QualityControl::Remedy.Attempt", bug_id: bug,
                  reference: { value: "REM-1" }, sequence: { value: 1 },
                  engineer: { value: "Claude QA" }, approach: { value: "recursive coercion" })
      qc.dispatch("QualityControl::Remedy.Abandon", id: "REM-1",
                  reason: { value: "architectural" })
      qc.dispatch("QualityControl::Ticket.Draft",
                  bug_id: bug, remedy_id: "REM-1",
                  reference: { value: "TK-1" },
                  repository: { value: "chrisyoung/hecksagain" },
                  title: { value: "Nested VO invariants" }, body: { value: "..." })
      "TK-1"
    end

    it "refuses a repository that is not owner/name" do
      expect {
        qc.dispatch("QualityControl::Ticket.Draft",
                    bug_id: "BUG#2", remedy_id: "REM-1",
                    reference: { value: "TK-X" }, repository: { value: "hecksagain" },
                    title: { value: "x" }, body: { value: "y" })
      }.to raise_error(Hecksagain::Runtime::DOMAIN_REFUSALS.first.superclass)
    end

    it "keeps a submitted-and-unanswered filing visible" do
      ticket = drafted_ticket
      qc.dispatch("QualityControl::Ticket.Submit", id: ticket)

      expect(qc.query("QualityControl::Ticket.Submitting").map { |r| r[:reference][:value] })
        .to eq([ticket])
    end

    it "records what the tracker gave back" do
      ticket = drafted_ticket
      qc.dispatch("QualityControl::Ticket.Submit", id: ticket)
      handle = qc.dispatch("QualityControl::Ticket.Filed", id: ticket,
                           number: { value: 43 },
                           url: { value: "https://github.com/chrisyoung/hecksagain/issues/43" })

      expect(handle.state[:number][:value]).to eq(43)
      expect(qc.query("QualityControl::Ticket.Submitting")).to be_empty
      expect(qc.query("QualityControl::Ticket.Filed").map { |r| r[:number][:value] }).to eq([43])
    end

    it "records a refusal and lets the draft be revised before retrying" do
      ticket = drafted_ticket
      qc.dispatch("QualityControl::Ticket.Submit", id: ticket)
      qc.dispatch("QualityControl::Ticket.Failed", id: ticket,
                  refusal: { value: "gh: authentication required" })

      expect(qc.query("QualityControl::Ticket.Failed").map { |r| r[:refusal][:value] })
        .to eq(["gh: authentication required"])

      handle = qc.dispatch("QualityControl::Ticket.Retry", id: ticket)
      expect(handle.state[:status]).to eq("drafted")
    end

    it "will not withdraw a ticket the tracker already has" do
      ticket = drafted_ticket
      qc.dispatch("QualityControl::Ticket.Submit", id: ticket)
      qc.dispatch("QualityControl::Ticket.Filed", id: ticket,
                  number: { value: 43 }, url: { value: "https://example.com/43" })

      expect { qc.dispatch("QualityControl::Ticket.Withdraw", id: ticket) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "filed"/)
    end
  end

  describe "blocking" do
    it "points a reader at the blocker instead of the symptom" do
      session = session_with_failing_test
      blocker = discover_bug(session, reference: "BUG#2", severity: "high")
      qc.dispatch("QualityControl::Bug.Discover",
                  session_id: session, reference: { value: "BUG#3" }, sequence: { value: 3 },
                  domain: { value: "Pizzas" },
                  title: { value: "Invalid closed-set values accepted" },
                  symptom: { value: "Size 'medium' is accepted where only small/large are declared" },
                  expectation: { value: "an InvariantViolation" },
                  severity: { value: "high" })
      qc.dispatch("QualityControl::Bug.Block", id: "BUG#3", blocked_by: { value: blocker })

      blocked = qc.query("QualityControl::Bug.Blocked").map { |r| r[:reference][:value] }
      expect(blocked).to eq(["BUG#3"])

      qc.dispatch("QualityControl::Bug.Unblock", id: "BUG#3", blocked_by: { value: "none" })
      expect(qc.query("QualityControl::Bug.Blocked")).to be_empty
    end
  end

  describe "coverage, counted rather than tallied" do
    it "answers which domains and categories have actually been attacked" do
      session = session_with_failing_test
      qc.dispatch("QualityControl::Session.Test", id: session,
                  domain: { value: "Banking" }, category: { value: "boundary" },
                  subject: { value: "Banking::Account.Debit" },
                  expectation: { value: "an overdraft is refused" },
                  location: { value: "spec/qa_bugs_spec.rb" })

      pizzas = qc.query("QualityControl::Session.TestCase.ForDomain", domain: { value: "Pizzas" })
      expect(pizzas.length).to eq(1)

      expect(qc.query("QualityControl::Session.TestCase.ForDomain", domain: { value: "Compliance" })).to be_empty
      expect(qc.query("QualityControl::Session.TestCase.InCategory", category: { value: "boundary" }).length).to eq(1)
    end

    it "stamps each test case with the session that ran it" do
      session = session_with_failing_test
      row = qc.query("QualityControl::Session.TestCase.Failing").first

      expect(row[:session]).to eq(session)
      expect(row[:expectation][:value]).to eq("a whitespace-only pizza name is refused")
    end

    it "counts a session's bugs instead of holding a counter for them" do
      session = session_with_failing_test
      discover_bug(session)

      expect(qc.query("QualityControl::Bug.FoundIn", session_id: { value: session }).length).to eq(1)
    end
  end

  describe "graduation" do
    it "moves a passing test out of the bug suite and refuses to move a failing one" do
      session = session_with_failing_test

      expect {
        qc.dispatch("QualityControl::Session.TestCase.Graduate", id: session, sequence: { value: 1 },
                    location: { value: "spec/pizzas_spec.rb" })
      }.to raise_error(Hecksagain::Runtime::LifecycleRefused, /outcome is "failing"/)

      qc.dispatch("QualityControl::Session.TestCase.Rerun", id: session, sequence: { value: 1 })
      qc.dispatch("QualityControl::Session.TestCase.Pass", id: session, sequence: { value: 1 },
                  observation: { value: "refused, as expected, since 63750a3" })

      expect(qc.query("QualityControl::Session.TestCase.ReadyToGraduate").length).to eq(1)

      qc.dispatch("QualityControl::Session.TestCase.Graduate", id: session, sequence: { value: 1 },
                  location: { value: "spec/pizzas_spec.rb" })

      expect(qc.query("QualityControl::Session.TestCase.ReadyToGraduate")).to be_empty
    end
  end
end
