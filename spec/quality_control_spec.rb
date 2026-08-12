require "spec_helper"

# THE QA LEDGER, EXERCISED THE WAY IT WILL ACTUALLY BE USED.
#
# Booted against Memory rather than the chapter's own Postgres binding — a
# spec that wrote to the real ledger would leave it different after every run,
# which is the one thing a durable store must not do to its own test. Only the
# WIRING is swapped; the chapter under test is the file the tool boots.
#
# Written through the facade: a creating verb is a module method returning the
# record in hand, every other verb is a method on that record. Queries and
# entity commands have no door and go through the runtime — the two helpers at
# the top are the only places this file reaches past it.
RSpec.describe "QualityControl" do
  QC_ROOT = File.join(InMemoryDomain::ROOT, "qa/bluebook").freeze

  class StubTracker
    # THE ADAPTER RETURNS WHAT THE ANSWERING COMMAND TAKES. The answer is
    # spread into the event payload, and a policy re-enters with that
    # payload verbatim — so these keys are `Ticket.Filed`'s arguments, in the
    # shape the runtime coerces.
    def file(**) = { "number" => { "value" => 43 }, "url" => { "value" => "https://example.com/issues/43" } }
  end

  class RefusingTracker
    def file(**) = raise IOError, "the token expired"
  end

  def boot_quality_control(tracker = StubTracker)
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(File.join(QC_ROOT, "quality_control.bluebook"))

      Hecksagain::Adapters.send(:remove_const, :QcTracker) if Hecksagain::Adapters.const_defined?(:QcTracker, false)
      Hecksagain::Adapters.const_set(:QcTracker, tracker)
      Hecks.adapter("QcTracker") { port "IssueTracker" }

      Hecks.hecksagon "QualityControl" do
        ::QualityControl::Target.persisted_by("Memory")
        ::QualityControl::Sweep.persisted_by("Memory")
        ::QualityControl::Bug.persisted_by("Memory")
        ::QualityControl::Ticket.persisted_by("Memory")
        ::QualityControl::Clearance.persisted_by("Memory")

        ::QualityControl::Ticket.port "IssueTracker" do
          asks "File" do
            reference_to Ticket, as: :id
            answers "IssueFiled"
            refuses "IssueFilingRefused"
          end

          tells "Closed" do
            reference_to Ticket, as: :id
            emits "IssueClosedUpstream"
          end
        end
      end
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
  end

  let(:runtime) { boot_quality_control }

  def rows(query, **args) = runtime.query("QualityControl::#{query}", **args)
  def references(query, **args) = rows(query, **args).map { |row| row[:reference][:value] }
  def check(sweep, verb, **args) = runtime.dispatch("QualityControl::Sweep.Check.#{verb}", id: sweep.id, **args)

  def a_target(reference = "banking", path = "examples/banking")
    runtime
    QualityControl::Target.identify(reference: { value: reference }, path: { value: path })
  end

  def a_sweep(target = nil, reference: "SW-1", engineer: "Claude QA")
    target ||= a_target
    QualityControl::Sweep.open(target_id: target.id, reference: { value: reference },
                               engineer: { value: engineer })
  end

  def a_check(sweep, subject: "Banking::Account.Freeze", expectation: "a frozen account refuses a second freeze")
    sweep.check(subject: { value: subject }, expectation: { value: expectation })
  end

  def a_bug(sweep, reference: "BUG#1", sequence: 1)
    QualityControl::Bug.log(
      sweep_id: sweep.id,
      reference: { value: reference }, sequence: { value: sequence },
      title: { value: "as: is accepted and does not alias" },
      demonstration: { value: 'rspec spec/qa_bugs_spec.rb -e "aliasing"' },
      symptom: { value: "the alias is ignored and the original name still answers" },
      expectation: { value: "the aliased name answers and the original does not" }
    )
  end

  # ── the rotation ─────────────────────────────────────────────────────

  describe "the rotation" do
    it "offers the least recently swept first" do
      swept = a_target("banking")
      swept.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })
      swept.release(last_swept: { value: 1_000 })
      a_target("pizzas", "examples/pizzas")

      # "never" sorts before any sweep reference, which is the ordering the
      # rotation wants: nobody has ever looked at pizzas.
      expect(references("Target.Rotation").first).to eq("pizzas")
    end

    it "shows what nobody has ever swept, which no count of checks could" do
      a_target("compliance", "examples/compliance")

      expect(references("Target.Untouched")).to eq(["compliance"])
      expect(rows("Sweep.Check.ForSubject", subject: { value: "compliance" })).to be_empty
    end

    # TWO AGENTS, ONE CHAPTER. The lifecycle is the lock: one transition
    # wins, the other is refused and takes the next chapter.
    it "gives a chapter to one agent and refuses the other" do
      target = a_target
      target.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })

      expect(target.held_by.to_h).to eq(value: "agent-one")

      expect {
        target.claim(held_by: { value: "agent-two" }, now: { value: 1_060 }, window: { value: 900 })
      }.to raise_error(Hecksagain::Runtime::GivenNotMet, /not taken from the agent holding it/)
    end

    # AND THE FAILURE MODE EVERY LOCK HAS. An agent that dies holds the
    # chapter forever unless the claim can go stale.
    it "lets the next agent take a claim whose holder has gone quiet" do
      target = a_target
      target.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })

      target.claim(held_by: { value: "agent-two" }, now: { value: 1_000 + 900 }, window: { value: 900 })

      expect(target.held_by.to_h).to eq(value: "agent-two")
    end

    it "puts a released chapter back at the end of the rotation" do
      target = a_target
      target.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })
      target.release(last_swept: { value: 1_000 })

      expect(target.status).to eq("waiting")
      expect(rows("Target.Untouched")).to be_empty
    end
  end

  # ── the other queue ──────────────────────────────────────────────────

  # SWEEPING IS NOT THE ONLY WAY TO GET WORK. An agent that is not sweeping
  # takes the next open bug off the queue and fixes that instead — so a bug
  # is claimed for the same reason a chapter is.
  describe "taking a bug off the queue" do
    it "offers open bugs nobody is holding, oldest first" do
      sweep = a_sweep
      a_bug(sweep, reference: "BUG#2", sequence: 2)
      a_bug(sweep, reference: "BUG#1", sequence: 1)

      expect(references("Bug.Queue")).to eq(["BUG#1", "BUG#2"])
      expect(rows("Bug.InHand")).to be_empty
    end

    it "takes it out of the queue and into somebody's hands" do
      bug = a_bug(a_sweep)
      bug.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })

      expect(rows("Bug.Queue")).to be_empty
      expect(references("Bug.InHand")).to eq([bug.id])
    end

    it "refuses a second agent while the first is still on it" do
      bug = a_bug(a_sweep)
      bug.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })

      expect {
        bug.claim(held_by: { value: "agent-two" }, now: { value: 1_060 }, window: { value: 900 })
      }.to raise_error(Hecksagain::Runtime::GivenNotMet, /not taken from the agent holding it/)
    end

    it "lets the next agent take one whose holder has gone quiet" do
      bug = a_bug(a_sweep)
      bug.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })
      bug.claim(held_by: { value: "agent-two" }, now: { value: 1_900 }, window: { value: 900 })

      expect(bug.held_by.to_h).to eq(value: "agent-two")
    end

    # HOLDING IS ORTHOGONAL TO THE FIX. An agent picks up a bug that is
    # already `investigating` without moving it, which is why the claim is a
    # `given` here and a lifecycle edge on Target.
    it "does not move the fix along" do
      bug = a_bug(a_sweep)
      bug.investigate(site: { value: "x.rb:1" }, cause: { value: "y" })
      bug.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })

      expect(bug.status).to eq("investigating")
    end

    it "puts it back on the queue when somebody gives up on it" do
      bug = a_bug(a_sweep)
      bug.claim(held_by: { value: "agent-one" }, now: { value: 1_000 }, window: { value: 900 })
      bug.drop(held_by: { value: "nobody" })

      expect(references("Bug.Queue")).to eq([bug.id])
    end
  end

  # ── the check ────────────────────────────────────────────────────────

  describe "a check" do
    it "is written down with its expectation before anything is observed" do
      sweep = a_sweep
      a_check(sweep)

      made = sweep.checks.first
      expect(made[:expectation][:value]).to eq("a frozen account refuses a second freeze")
      expect(made[:observation]).to be_nil
      expect(sweep.made.to_h).to eq(value: 1)
    end

    # `surprising` IS NOT `failed` — it covers the crash and the quiet
    # divergence without prejudging which, and the quiet one is the point.
    it "separates what the chapter promised from what surprised" do
      sweep = a_sweep
      a_check(sweep)
      a_check(sweep, subject: "Banking::Account.Open", expectation: "as: aliases the argument")

      check(sweep, "Held", sequence: { value: 1 }, observation: { value: "refused, as declared" })
      check(sweep, "Surprised", sequence: { value: 2 },
                   observation: { value: "as: was accepted and the original name still answered" })

      surprising = rows("Sweep.Check.Surprising")
      expect(surprising.length).to eq(1)
      expect(surprising.first[:subject][:value]).to eq("Banking::Account.Open")
      expect(surprising.first[:sweep]).to eq(sweep.id)
    end

    it "counts a run that settled nothing as neither" do
      sweep = a_sweep
      a_check(sweep)
      check(sweep, "Unsettled", sequence: { value: 1 }, observation: { value: "the adapter was not reachable" })

      expect(rows("Sweep.Check.Surprising")).to be_empty
      expect(rows("Sweep.Check.Unsettled").length).to eq(1)
    end
  end

  # ── gates bend, and leave a mark ─────────────────────────────────────

  describe "a gate" do
    it "refuses a sweep that checked nothing" do
      sweep = a_sweep

      expect { sweep.conclude(notes: { value: "Nothing was run, but here are forty characters of notes." }) }
        .to raise_error(Hecksagain::Runtime::GivenNotMet, /checked nothing/)
    end

    it "lets you through with a reason, and counts it" do
      sweep = a_sweep
      sweep.waive(reason: { value: "the chapter would not boot; recording the pass so the rotation moves on" })

      expect { sweep.conclude(notes: { value: "Could not boot the chapter at all — see the waiver." }) }
        .not_to raise_error
      expect(references("Sweep.Waived")).to eq([sweep.id])
    end

    it "refuses notes too short to be a finding" do
      sweep = a_sweep
      a_check(sweep)

      expect { sweep.conclude(notes: { value: "done" }) }
        .to raise_error(Hecksagain::Runtime::InvariantViolation, /what it learned/)
    end
  end

  # ── the one absolute rule ────────────────────────────────────────────

  # A GATE CAN BE WAIVED; AN ARGUMENT CANNOT. "No bug without the test that
  # proves it" is a required argument for exactly that reason.
  describe "no bug without evidence" do
    it "cannot be logged without the test that proves it" do
      sweep = a_sweep

      expect {
        QualityControl::Bug.log(
          sweep_id: sweep.id, reference: { value: "BUG#2" }, sequence: { value: 2 },
          title: { value: "something is off" },
          symptom: { value: "it looked wrong" },
          expectation: { value: "it should not" }
        )
      }.to raise_error(Hecksagain::Runtime::AbsentArgument, /demonstration/)
    end

    it "is born proven — there is no state for an unproven report" do
      bug = a_bug(a_sweep)

      expect(bug.status).to eq("logged")
      expect(bug.demonstration.to_h[:value]).to include("rspec")
    end
  end

  describe "the fix" do
    def investigated
      bug = a_bug(a_sweep)
      bug.investigate(site: { value: "lib/hecksagain/bluebook/dsl/query_builder.rb:88" },
                      cause: { value: "the alias is parsed and then dropped before the IR is built" })
    end

    it "will not take a commit that is not a sha" do
      expect { investigated.fix(commit: { value: "later" }) }
        .to raise_error(Hecksagain::Runtime::TypeMismatch, /must match/)
    end

    it "will not be verified with nothing behind it" do
      expect { investigated.fix(commit: { value: "4f2a19c" }).verify }
        .to raise_error(Hecksagain::Runtime::AbsentArgument, /evidence/)
    end

    it "keeps what was actually run, so the claim is checkable" do
      bug = investigated.fix(commit: { value: "4f2a19c" })
      bug.verify(evidence: { value: "rspec --order random: 1335 examples, 0 failures, seed 12345" })

      expect(bug.status).to eq("verified")
      expect(bug.verification.to_h[:value]).to include("seed 12345")
    end

    it "cannot be fixed before anybody has looked at it" do
      expect { a_bug(a_sweep).fix(commit: { value: "4f2a19c" }) }
        .to raise_error(Hecksagain::Runtime::LifecycleRefused, /moves it only from "investigating"/)
    end

    it "says what would move a bug it stopped on" do
      bug = a_bug(a_sweep)

      expect { bug.pause(reason: { value: "affects the whole type system" }) }
        .to raise_error(Hecksagain::Runtime::AbsentArgument, /next_step/)

      bug.pause(reason: { value: "affects the whole type system" },
                next_step: { value: "architecture review — should coercion recurse into nested value objects?" })
      expect(references("Bug.Paused")).to eq([bug.id])
    end
  end

  # ── the outside world ────────────────────────────────────────────────

  describe "raising a ticket" do
    def a_paused_bug
      bug = a_bug(a_sweep)
      bug.pause(reason: { value: "architectural" }, next_step: { value: "architecture review" })
    end

    def raise_ticket(bug, reference: "TK-1")
      QualityControl::Ticket.raise_(
        bug_id: bug.id, reference: { value: reference },
        repository: { value: "chrisyoung/hecksagain" },
        title: { value: "as: is accepted and does not alias" },
        body: { value: "see the demonstration" }
      ); runtime.dispatch("QualityControl::Ticket.Submit", id: "TK-1")
    rescue NoMethodError
      QualityControl::Ticket.public_send(
        :raise, bug_id: bug.id, reference: { value: reference },
        repository: { value: "chrisyoung/hecksagain" },
        title: { value: "as: is accepted and does not alias" },
        body: { value: "see the demonstration" }
      ); runtime.dispatch("QualityControl::Ticket.Submit", id: "TK-1")
    end

    it "cannot be raised for a bug that does not exist" do
      a_sweep

      expect {
        QualityControl::Ticket.public_send(
          :raise, bug_id: "BUG#nope", reference: { value: "TK-9" },
          repository: { value: "chrisyoung/hecksagain" },
          title: { value: "x" }, body: { value: "y" }
        )
      }.to raise_error(Hecksagain::Runtime::NotFound)
    end

    # THE DOMAIN DOES THE ASKING. `Raise` records the intent; the policy fires
    # the port; the adapter answers; a second policy records what came back.
    it "files it through the port and records what the tracker said" do
      ticket = raise_ticket(a_paused_bug)

      expect(runtime.events.map(&:name)).to include("IssueFiled", "TicketFiled")
      expect(rows("Ticket.Filed").first[:number][:value]).to eq(43)
    end

    # EVERY FAILURE IS AN ANSWER — the raise from the far side becomes the
    # refusal the chapter named, and the retry policy takes it from there.
    it "turns a dead token into the refusal it named, and asks again" do
      runtime = boot_quality_control(RefusingTracker)
      allow(self).to receive(:runtime).and_return(runtime) if respond_to?(:allow)

      target = QualityControl::Target.identify(reference: { value: "banking" }, path: { value: "examples/banking" })
      sweep  = QualityControl::Sweep.open(target_id: target.id, reference: { value: "SW-1" },
                                          engineer: { value: "Claude QA" })
      bug    = QualityControl::Bug.log(
        sweep_id: sweep.id, reference: { value: "BUG#1" }, sequence: { value: 1 },
        title: { value: "t" }, demonstration: { value: "rspec x" },
        symptom: { value: "s" }, expectation: { value: "e" }
      )
      bug.pause(reason: { value: "architectural" }, next_step: { value: "review" })

      QualityControl::Ticket.public_send(
        :raise, bug_id: bug.id, reference: { value: "TK-1" },
        repository: { value: "chrisyoung/hecksagain" },
        title: { value: "x" }, body: { value: "y" }
      ); runtime.dispatch("QualityControl::Ticket.Submit", id: "TK-1")

      names = runtime.events.map(&:name)
      expect(names).to include("IssueFilingRefused", "TicketFilingRefused", "TicketRetried")
      expect(runtime.query("QualityControl::Ticket.All").first[:refusal][:value]).to include("token expired")
    end
  end

  # ── is it safe to ship ───────────────────────────────────────────────

  # NOT A QUESTION ABOUT NOW — a record about a commit. CI went green at two
  # o'clock; you have pushed twice since; the green belongs to what it ran
  # against, and the new commit simply has none of its own.
  describe "clearance" do
    it "clears the exact commit it ran against, and nothing else" do
      runtime
      cleared = QualityControl::Clearance.start(commit: { value: "4f2a19c" })
      cleared.passed(summary: { value: "1335 examples, 0 failures, seed 12345" })
      QualityControl::Clearance.start(commit: { value: "bc91d76" })

      expect(rows("Clearance.For", commit: { value: "4f2a19c" }).length).to eq(1)
      expect(rows("Clearance.For", commit: { value: "bc91d76" })).to be_empty
    end

    it "answers no for a commit nobody has run at all" do
      runtime

      expect(rows("Clearance.For", commit: { value: "deadbee" })).to be_empty
    end

    it "keeps what the run actually said when it went red" do
      runtime
      run = QualityControl::Clearance.start(commit: { value: "0d85613" })
      run.failed(summary: { value: "1335 examples, 5 failures, seed 12345" })

      expect(rows("Clearance.Red").first[:summary][:value]).to include("5 failures")
    end
  end
end
