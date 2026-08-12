require "spec_helper"

# THE QA LEDGER, EXERCISED THE WAY IT WILL ACTUALLY BE USED.
#
# Booted against Memory rather than against `qa/bluebook/quality_control.hecksagon`'s
# own Heki binding — a spec that wrote to `qa/data/` would leave the real ledger
# different after every run, which is the one thing a durable store must not do
# to its own test. Only the WIRING is swapped; the chapter under test is the
# same file the tool boots.
#
# WRITTEN THROUGH THE FACADE, not through dispatch strings. `bind_runtime`
# installs the door `spec/facade/handle_spec.rb` uses, so a creating verb is a
# module method returning the record in hand and every other verb is a method
# ON that record, with the identity supplied from its own state:
#
#     bug = QualityControl::Bug.discover(...)   # not runtime.dispatch("...")
#     bug.reproduce(demonstration: ...)         # not ..., id: bug_reference
#     bug.status                                # not handle.state[:status]
#
# The difference is not cosmetic. Half of what a dispatch-string spec asserts
# is that the spec passed the right id to the right verb, which is a fact about
# the spec; a `bug.reproduce` that refuses is a fact about the chapter.
#
# TWO THINGS STILL GO THROUGH THE RUNTIME, because the facade has no sugar for
# them: queries (`runtime.query`) and ENTITY commands, whose verb is
# `Domain::Aggregate.Entity.Command` and which `Handle#define_verb_methods`
# does not reach — it walks `ir.commands`, and an entity's commands are not
# among them. `test_case` below is the one helper that wraps that.
RSpec.describe "QualityControl" do
  QC_BLUEBOOK = File.join(InMemoryDomain::ROOT, "qa/bluebook/quality_control.bluebook").freeze

  # `bind_runtime`, where an ordinary spec here returns a bare Dispatcher — it
  # is what installs `QualityControl::Bug` and friends as real constants. The
  # dispatcher still comes back, for the queries and entity commands above.
  def boot_quality_control
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      # The extraction port — `identified_by` recovers its own predicate's
      # source through it, so a boot without it refuses at the first aggregate
      # rather than at dispatch.
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(QC_BLUEBOOK)

      Hecks.hecksagon("QualityControl") do
        ::QualityControl::Session.persisted_by("Memory")
        ::QualityControl::Bug.persisted_by("Memory")
        ::QualityControl::Remedy.persisted_by("Memory")
        ::QualityControl::Ticket.persisted_by("Memory")
        ::QualityControl::Target.persisted_by("Memory")
      end
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
  end

  let(:runtime) { boot_quality_control }

  # ── the shapes every example starts from ───────────────────────────────

  def a_session(reference: "QA-2026-08-11", engineer: "Claude QA")
    runtime
    QualityControl::Session.start(reference: { value: reference }, engineer: { value: engineer })
  end

  def a_test(session, domain: "Pizzas", category: "empty",
             subject: "Pizzas::Order.CreatePizza",
             expectation: "a whitespace-only pizza name is refused",
             location: 'spec/qa_bugs_spec.rb -e "BUG#4"')
    session.test(domain: { value: domain }, category: { value: category },
                 subject: { value: subject }, expectation: { value: expectation },
                 location: { value: location })
  end

  # THE ONLY TWO PLACES THIS FILE REACHES PAST THE FACADE, and both are here
  # so the rest of the spec reads as ordinary Ruby.
  #
  # An ENTITY command has no door. `Facade::Surface` installs one module per
  # AGGREGATE and `Handle#define_verb_methods` walks `ir.commands` — an
  # entity's commands are in neither, so `session.pass(...)` does not exist
  # and the verb has to be spelled `Domain::Aggregate.Entity.Command` with the
  # sequence passed by hand. Checked, not assumed: the door's singleton
  # methods are `[:all, :commands, :count, :events, :find, :fqn, :ir, :port,
  # :repository, :start]` and nothing else.
  def entity_command(session, verb, **args)
    runtime.dispatch("QualityControl::Session.TestCase.#{verb}", id: session.id, **args)
  end

  def settle(session, sequence, verb, observation: "the command succeeded and stored '   '")
    extra = verb == "Rerun" ? {} : { observation: { value: observation } }
    entity_command(session, verb, sequence: { value: sequence }, **extra)
  end

  def graduate(session, sequence, location)
    entity_command(session, "Graduate", sequence: { value: sequence }, location: { value: location })
  end

  # The only honest way a bug comes into being: a test written first, run, and
  # found to be wrong about the system.
  def session_with_failing_test(reference: "QA-2026-08-11")
    session = a_session(reference: reference)
    a_test(session)
    settle(session, 1, "Fail", observation: "the command succeeded and stored '   '")
    session
  end

  def a_bug(session, reference: "BUG#4", severity: "medium", domain: "Pizzas", sequence: 4)
    QualityControl::Bug.discover(
      session_id: session.id,
      reference: { value: reference }, sequence: { value: sequence },
      domain: { value: domain },
      title: { value: "Whitespace-only strings accepted as names" },
      symptom: { value: "PizzaName '   ' is stored verbatim" },
      expectation: { value: "an InvariantViolation, as for the empty string" },
      severity: { value: severity }
    )
  end

  def rows(query, **args) = runtime.query("QualityControl::#{query}", **args)
  def references(query, **args) = rows(query, **args).map { |row| row[:reference][:value] }

  # ── the session ────────────────────────────────────────────────────────

  describe "the session" do
    it "numbers its own test cases and counts them" do
      session = session_with_failing_test
      a_test(session, category: "boundary", expectation: "a zero price is refused")

      expect(session.tested.to_h).to eq(value: 2)
      expect(session.test_cases.map { |t| t[:sequence][:value] }).to eq([1, 2])
    end

    it "refuses to complete a session that tested nothing" do
      session = a_session(reference: "QA-EMPTY")

      expect {
        session.complete(notes: { value: "Nothing was run, but here are forty characters of notes." })
      }.to raise_error(Hecksagain::Runtime::GivenNotMet, /tested nothing/)
    end

    it "refuses a session note too short to be a finding" do
      expect { session_with_failing_test.complete(notes: { value: "done" }) }
        .to raise_error(Hecksagain::Runtime::InvariantViolation, /what it learned/)
    end

    it "refuses to write a test case into a paused session" do
      session = session_with_failing_test
      session.pause

      expect { a_test(session, category: "state") }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "paused"/)
    end
  end

  # ── the gate the whole chapter stands on ───────────────────────────────

  # It costs no predicate: the machine has no edge out of `found` except
  # `Reproduce`, so the refusal is `LifecycleRefused` naming the states it
  # would have moved from. Asserted on the wording as well as the class —
  # that sentence is what a QA agent reads when the tool says no.
  describe "the reproduce gate" do
    it "refuses to investigate a bug nobody has reproduced" do
      bug = a_bug(session_with_failing_test)

      expect {
        bug.investigate(site: { value: "examples/pizzas/bluebook/pizzas.bluebook" },
                        cause: { value: "the predicate sublanguage has no .strip" })
      }.to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "reproduced"/)
    end

    it "refuses to dismiss a bug nobody has reproduced" do
      bug = a_bug(session_with_failing_test)

      expect { bug.dismiss(reason: { value: "probably correct behaviour" }) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "found"/)
    end

    it "lists it as unreproduced until a demonstration exists" do
      bug = a_bug(session_with_failing_test)
      expect(references("Bug.Unreproduced")).to eq([bug.id])

      bug.reproduce(demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#4"' })

      expect(bug.status).to eq("reproduced")
      expect(rows("Bug.Unreproduced")).to be_empty
    end
  end

  # ── the commit rule ────────────────────────────────────────────────────

  describe "the commit rule" do
    def investigated_bug
      bug = a_bug(session_with_failing_test)
      bug.reproduce(demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#4"' })
      bug.investigate(site: { value: "examples/pizzas/bluebook/pizzas.bluebook" },
                      cause: { value: "the predicate sublanguage has no .strip" })
    end

    it "cannot mark a bug fixed without a commit at all" do
      expect { investigated_bug.fix }.to raise_error(Hecksagain::Runtime::AbsentArgument)
    end

    it "refuses a commit that is not a sha" do
      expect { investigated_bug.fix(commit: { value: "later" }) }
        .to raise_error(Hecksagain::Runtime::TypeMismatch, /must match/)
    end

    it "takes a real sha and only then allows verification" do
      bug = investigated_bug.fix(commit: { value: "63750a3" })

      expect(bug.commit.to_h).to eq(value: "63750a3")
      expect(references("Bug.ReadyToVerify")).to eq([bug.id])

      verified = bug.verify(evidence: { value: "rspec --order random: 1247 examples, 0 failures, seed 41022" })
      expect(verified.status).to eq("verified")
      expect(verified.verification.to_h[:value]).to include("seed")
    end

    it "cannot verify a bug that was never fixed" do
      expect { investigated_bug.verify(evidence: { value: "rspec: 1247 examples, 0 failures" }) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "fixed"/)
    end
  end

  # ── fix first, file second ─────────────────────────────────────────────

  describe "fix first, file second" do
    def paused_bug
      bug = a_bug(session_with_failing_test, reference: "BUG#2", severity: "high")
      bug.reproduce(demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#2"' })
      bug.investigate(site: { value: "lib/hecksagain/runtime/value/coercion.rb" },
                      cause: { value: "Value::Coercion.build does not recurse into nested value objects" })
    end

    def an_attempt(bug, reference: "REM-1")
      QualityControl::Remedy.attempt(
        bug_id: bug.id, reference: { value: reference }, sequence: { value: 1 },
        engineer: { value: "Claude QA" },
        approach: { value: "recurse in Value::Coercion.build over nested value objects" }
      )
    end

    def draft(bug, remedy, reference: "TK-1")
      QualityControl::Ticket.draft(
        bug_id: bug.id, remedy_id: remedy.is_a?(String) ? remedy : remedy.id,
        reference: { value: reference },
        repository: { value: "chrisyoung/hecksagain" },
        title: { value: "Nested value object invariants are not validated" },
        body: { value: "Why not fixed: requires a refactor of the coercion pipeline." }
      )
    end

    # THE STRONGEST RULE IN THE CHAPTER, and it is not a predicate: a
    # reference must resolve at dispatch, so a ticket that cannot name an
    # attempt cannot be drafted at all.
    it "refuses to draft a ticket that cannot name an attempt" do
      expect { draft(paused_bug, "REM-nope") }.to raise_error(Hecksagain::Runtime::NotFound)
    end

    it "drafts once an attempt has been abandoned, and carries its reason" do
      bug    = paused_bug
      remedy = an_attempt(bug)
      remedy.touch(path: { value: "lib/hecksagain/runtime/value/coercion.rb" },
                   note: { value: "tried a recursive build; broke era reconstruction" })
      remedy.abandon(reason: { value: "requires a refactor of the whole coercion pipeline" })

      expect(remedy.changes.length).to eq(1)
      expect(remedy.status).to eq("abandoned")

      # The reason travels: what the attempt said on the day it ran out is
      # what the bug now says about why it stopped.
      bug.pause(reason: remedy.reason.to_h,
                next_step: { value: "architecture review — should coercion recurse into nested value objects?" })

      expect { draft(bug, remedy) }.not_to raise_error
      expect(references("Bug.Paused")).to eq([bug.id])
    end

    it "surfaces a ticket drafted while its attempt is still live" do
      bug    = paused_bug
      remedy = an_attempt(bug)
      draft(bug, remedy)

      expect(references("Ticket.RestingOnLiveRemedy")).to eq(["TK-1"])
      expect(references("Remedy.Unresolved")).to eq(["REM-1"])
    end
  end

  # ── the tracker is somebody else's database ────────────────────────────

  describe "the tracker is somebody else's database" do
    def drafted_ticket
      bug = a_bug(session_with_failing_test, reference: "BUG#2", severity: "high")
      bug.reproduce(demonstration: { value: "rspec ..." })
      remedy = QualityControl::Remedy.attempt(
        bug_id: bug.id, reference: { value: "REM-1" }, sequence: { value: 1 },
        engineer: { value: "Claude QA" }, approach: { value: "recursive coercion" }
      )
      remedy.abandon(reason: { value: "architectural" })
      QualityControl::Ticket.draft(
        bug_id: bug.id, remedy_id: remedy.id,
        reference: { value: "TK-1" }, repository: { value: "chrisyoung/hecksagain" },
        title: { value: "Nested VO invariants" }, body: { value: "..." }
      )
    end

    it "refuses a repository that is not owner/name" do
      bug    = a_bug(session_with_failing_test)
      remedy = QualityControl::Remedy.attempt(
        bug_id: bug.id, reference: { value: "REM-1" }, sequence: { value: 1 },
        engineer: { value: "Claude QA" }, approach: { value: "x" }
      )

      expect {
        QualityControl::Ticket.draft(
          bug_id: bug.id, remedy_id: remedy.id,
          reference: { value: "TK-X" }, repository: { value: "hecksagain" },
          title: { value: "x" }, body: { value: "y" }
        )
      }.to raise_error(Hecksagain::Runtime::TypeMismatch, /must match/)
    end

    it "keeps a submitted-and-unanswered filing visible" do
      ticket = drafted_ticket.submit

      expect(ticket.status).to eq("submitting")
      expect(references("Ticket.Submitting")).to eq(["TK-1"])
    end

    it "records what the tracker gave back" do
      ticket = drafted_ticket.submit
      ticket.filed(number: { value: 43 },
                   url: { value: "https://github.com/chrisyoung/hecksagain/issues/43" })

      expect(ticket.number.to_h).to eq(value: 43)
      expect(rows("Ticket.Submitting")).to be_empty
      expect(rows("Ticket.Open").map { |row| row[:number][:value] }).to eq([43])
    end

    it "records a refusal and lets the draft be revised before retrying" do
      ticket = drafted_ticket.submit
      ticket.failed(refusal: { value: "gh: authentication required" })

      expect(rows("Ticket.Refused").map { |row| row[:refusal][:value] })
        .to eq(["gh: authentication required"])
      expect(ticket.retry.status).to eq("drafted")
    end

    # THE POLICY THIS AGGREGATE SERVES: raise an issue only for a bug you
    # could not fix yourself. Fixing it afterwards is legitimate and common —
    # and leaves either a draft to withdraw or a public issue to close.
    it "surfaces a ticket about a bug the repository went on to fix itself" do
      ticket = drafted_ticket
      bug    = QualityControl::Bug.find("BUG#2")
      bug.investigate(site: { value: "coercion.rb" }, cause: { value: "recursion missing" })
      bug.fix(commit: { value: "abc1234" })

      expect(references("Ticket.RestingOnFixed")).to eq([ticket.id])

      ticket.withdraw
      expect(rows("Ticket.RestingOnFixed")).to be_empty
    end

    it "will not withdraw a ticket the tracker already has" do
      ticket = drafted_ticket.submit
      ticket.filed(number: { value: 43 }, url: { value: "https://example.com/43" })

      expect { ticket.withdraw }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "filed"/)
    end
  end

  # ── the ways a bug stops being a bug ───────────────────────────────────

  # Three words where `qa/FINDINGS.md` writes one ("NOT A BUG ✅"), and the
  # distinction is the only lesson any of them carries.
  describe "the ways a bug stops being a bug" do
    it "withdraws a report nobody could make happen, without ever reproducing it" do
      bug = a_bug(session_with_failing_test, reference: "BUG#7")

      # qa/FINDINGS.md #7, #8 and #9 exactly: logged, filed as public GitHub
      # issues, never reproduced, and correct code all along. Before
      # `Withdraw` existed, `found` had one exit and these were immortal.
      bug.withdraw(reason: { value: "the given was already there; the test asserted against the wrong command" })

      expect(bug.status).to eq("withdrawn")
      expect(references("Bug.Withdrawn")).to eq([bug.id])
      expect(rows("Bug.Unfixed")).to be_empty
    end

    it "refuses to withdraw a bug that was reproduced — that one is dismissed instead" do
      bug = a_bug(session_with_failing_test)
      bug.reproduce(demonstration: { value: "rspec ..." })

      expect { bug.withdraw(reason: { value: "never mind" }) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "found"/)

      bug.dismiss(reason: { value: "it happens exactly as described and that is the declared rule" })
      expect(rows("Bug.Dismissed").length).to eq(1)
    end

    it "marks a bug already tracked under another name, and stops counting it twice" do
      session = session_with_failing_test
      kept    = a_bug(session, reference: "BUG#12")
      twin    = a_bug(session, reference: "BUG#11", domain: "Runtime", sequence: 11)

      # The real collision: two records of one practice numbered the same bug
      # #11 here and #12 there, within hours, both already cited elsewhere.
      twin.duplicate(duplicate_of: { value: kept.id })

      expect(twin.status).to eq("duplicate")
      expect(rows("Bug.Duplicates").map { |row| row[:duplicate_of][:value] }).to eq([kept.id])
      expect(references("Bug.Unfixed")).to eq([kept.id])
    end

    it "counts everything once called a bug that is not one — the honesty check on a bug target" do
      session = session_with_failing_test
      kept    = a_bug(session, reference: "BUG#1", sequence: 1)
      gone    = a_bug(session, reference: "BUG#7", sequence: 7)
      gone.withdraw(reason: { value: "the code was right" })

      expect(references("Bug.Doubtful")).to eq([gone.id])
      expect(rows("Bug.All").length).to eq(2)
      expect(references("Bug.Unfixed")).to eq([kept.id])
    end
  end

  # ── two roles, and the handoff between them ────────────────────────────

  # `qa/senior/HANDBOOK.md` splits the practice: a junior agent finds bugs, a
  # senior fixes them, and the senior's first move is to read the diagnosis and
  # decide whether to agree.
  describe "the handoff" do
    def reproduced_bug
      bug = a_bug(session_with_failing_test)
      bug.reproduce(demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#4"' })
    end

    it "sends a bug back with what would have to be shown, without withdrawing it" do
      bug = reproduced_bug
      bug.dispute(reason: { value: "the test asserts against CreatePizza, but the invariant it names is on Purchase" })

      expect(bug.status).to eq("disputed")
      # Still owed work — a disputed bug is not a closed one.
      expect(references("Bug.Unfixed")).to eq([bug.id])
      expect(rows("Bug.Doubtful")).to be_empty
    end

    it "refuses to be fixed while it is disputed — it has to be shown again first" do
      bug = reproduced_bug
      bug.dispute(reason: { value: "not reproducible from this test" })

      expect { bug.investigate(site: { value: "x.rb:1" }, cause: { value: "y" }) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "reproduced"/)

      bug.reproduce(demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "BUG#4b" — now with the right command' })
      expect(bug.status).to eq("reproduced")
    end
  end

  describe "verification is evidence, not a claim" do
    def fixed_bug
      bug = a_bug(session_with_failing_test)
      bug.reproduce(demonstration: { value: "rspec ..." })
      bug.investigate(site: { value: "examples/pizzas/bluebook/pizzas.bluebook" },
                      cause: { value: "no .strip in the sublanguage" })
      bug.fix(commit: { value: "90b7ec1" })
    end

    it "cannot be verified with nothing behind it" do
      expect { fixed_bug.verify }.to raise_error(Hecksagain::Runtime::AbsentArgument, /evidence/)
    end

    it "keeps what was actually run, so the claim is checkable" do
      bug = fixed_bug.verify(evidence: { value: "rspec --order random: 1247 examples, 5 failures, seed 12345" })

      expect(bug.verification.to_h[:value]).to include("seed 12345")
    end
  end

  describe "a pause says what would move it" do
    def paused
      bug = a_bug(session_with_failing_test, severity: "high")
      bug.reproduce(demonstration: { value: "rspec ..." })
      bug
    end

    it "cannot be paused without a next step" do
      expect { paused.pause(reason: { value: "architectural" }) }
        .to raise_error(Hecksagain::Runtime::AbsentArgument, /next_step/)
    end

    it "keeps the question, and who has to answer it" do
      bug = paused.pause(reason: { value: "affects the whole type system" },
                         next_step: { value: "architecture review — should coercion recurse into nested VOs?" })

      expect(bug.next_step.to_h[:value]).to include("architecture review")
      expect(references("Bug.Paused")).to eq([bug.id])
    end
  end

  # ── the backlog ────────────────────────────────────────────────────────

  # The one thing no count of test cases can answer: an unswept target leaves
  # no trace anywhere else in the ledger.
  describe "the backlog" do
    def a_target(reference, path, kind, priority: nil)
      runtime
      target = QualityControl::Target.identify(
        reference: { value: reference }, path: { value: path }, kind: { value: kind },
        rationale: { value: "carries state, arithmetic and a list — three shapes at once" }
      )
      return target unless priority

      target.rank(priority: { value: priority },
                  rationale: { value: "the cheapest unswept surface with real invariants on it" })
    end

    it "shows what has never been swept, which nothing else in the ledger can" do
      a_target("till", "spec/fixtures/till.bluebook", "fixture")
      a_target("compliance", "examples/compliance/bluebook/compliance.bluebook", "domain")

      expect(references("Target.Untouched")).to match_array(%w[till compliance])

      # A test-case count cannot say this: an unswept target has no test cases,
      # and neither does a target nobody ever wrote down.
      expect(rows("Session.TestCase.ForDomain", domain: { value: "till" })).to be_empty
    end

    it "still reports a ranked target as untouched — ranking is not sweeping" do
      a_target("banking", "examples/banking/bluebook/banking.bluebook", "domain", priority: 2)

      expect(references("Target.Untouched")).to eq(["banking"])
    end

    it "orders the queue by priority and empties it as targets are swept" do
      a_target("till", "spec/fixtures/till.bluebook", "fixture", priority: 3)
      banking = a_target("banking", "examples/banking/bluebook/banking.bluebook", "domain", priority: 2)

      expect(references("Target.Queue")).to eq(%w[banking till])

      banking.sweep(last_swept: { value: session_with_failing_test.id })

      expect(banking.status).to eq("swept")
      expect(references("Target.Queue")).to eq(["till"])
      expect(references("Target.Untouched")).to eq(["till"])
    end

    it "tells a target that changed since its sweep apart from one never swept" do
      banking = a_target("banking", "examples/banking/bluebook/banking.bluebook", "domain", priority: 2)
      a_target("till", "spec/fixtures/till.bluebook", "fixture", priority: 3)
      banking.sweep(last_swept: { value: "QA-2026-08-11" })
      banking.restore

      expect(references("Target.Stale")).to eq(["banking"])
      expect(references("Target.Untouched")).to eq(["till"])
    end

    it "holds the planned categories, which is the half a test-case count cannot supply" do
      banking = a_target("banking", "examples/banking/bluebook/banking.bluebook", "domain", priority: 2)
      %w[boundary identity coercion].each do |category|
        banking.intend(name: { value: category },
                       why: { value: "composite identity and money invariants" })
      end

      planned = banking.plan.map { |category| category[:name] }
      expect(planned).to eq(%w[boundary identity coercion])

      # The gap that matters: planned minus applied. Neither half can answer it
      # alone, which is why the plan is declared and the application is not.
      applied = rows("Session.TestCase.InCategory", category: { value: "boundary" })
      expect(planned - applied.map { |t| t[:category][:value] }).to include("identity")
    end

    it "refuses to grow a plan after the target was swept" do
      banking = a_target("banking", "examples/banking/bluebook/banking.bluebook", "domain", priority: 2)
      banking.sweep(last_swept: { value: "QA-2026-08-11" })

      expect { banking.intend(name: { value: "identity" }, why: { value: "too late" }) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /status is "swept"/)
    end

    it "keeps a deliberate decision not to sweep, with its reason" do
      rust = a_target("rust", "rust/src", "runtime")
      rust.shelve(reason: { value: "no Ruby runtime to dispatch into; needs a different harness entirely" })

      expect(rows("Target.Shelved").map { |row| row[:reason][:value] })
        .to eq(["no Ruby runtime to dispatch into; needs a different harness entirely"])
      expect(rows("Target.Untouched")).to be_empty
    end
  end

  # ── blocking ───────────────────────────────────────────────────────────

  describe "blocking" do
    it "points a reader at the blocker instead of the symptom" do
      session = session_with_failing_test
      blocker = a_bug(session, reference: "BUG#2")
      blocked = a_bug(session, reference: "BUG#3", sequence: 3)

      blocked.block(blocked_by: { value: blocker.id })
      expect(references("Bug.Blocked")).to eq([blocked.id])

      blocked.unblock(blocked_by: { value: "none" })
      expect(rows("Bug.Blocked")).to be_empty
    end
  end

  # ── coverage, counted rather than tallied ──────────────────────────────

  describe "coverage, counted rather than tallied" do
    it "answers which domains and categories have actually been attacked" do
      session = session_with_failing_test
      a_test(session, domain: "Banking", category: "boundary",
             subject: "Banking::Account.Debit", expectation: "an overdraft is refused",
             location: "spec/qa_bugs_spec.rb")

      expect(rows("Session.TestCase.ForDomain", domain: { value: "Pizzas" }).length).to eq(1)
      expect(rows("Session.TestCase.ForDomain", domain: { value: "Compliance" })).to be_empty
      expect(rows("Session.TestCase.InCategory", category: { value: "boundary" }).length).to eq(1)
    end

    it "stamps each test case with the session that ran it" do
      session = session_with_failing_test
      row     = rows("Session.TestCase.Failing").first

      expect(row[:session]).to eq(session.id)
      expect(row[:expectation][:value]).to eq("a whitespace-only pizza name is refused")
    end

    it "counts a session's bugs instead of holding a counter for them" do
      session = session_with_failing_test
      a_bug(session)

      expect(rows("Bug.FoundIn", session_id: { value: session.id }).length).to eq(1)
    end
  end

  # ── graduation ─────────────────────────────────────────────────────────

  describe "graduation" do
    it "moves a passing test out of the bug suite and refuses to move a failing one" do
      session = session_with_failing_test

      expect { graduate(session, 1, "spec/pizzas_spec.rb") }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /outcome is "failing"/)

      settle(session, 1, "Rerun")
      settle(session, 1, "Pass", observation: "refused, as expected, since 63750a3")

      expect(rows("Session.TestCase.ReadyToGraduate").length).to eq(1)

      graduate(session, 1, "spec/pizzas_spec.rb")

      expect(rows("Session.TestCase.ReadyToGraduate")).to be_empty
    end
  end
end
