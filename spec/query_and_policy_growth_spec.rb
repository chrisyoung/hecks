require "spec_helper"
require "tempfile"

# Coverage for the four constructs docs/hecks-migration-findings.md items
# 10-13 name as "already implemented" in this fork: `group_by` (a query-
# level aggregation, git dc6f66f "query DSL: count/median/group_by
# aggregation + none_in_state anti-join"), policy `where field: value`
# and `for_each from:, where:` + `from_event` (git 9285a0f "policy DSL:
# conditional where clauses + for_each fan-out dispatch"), and
# `none_in_state` (same commit as group_by).
#
# Each of the four DSL builders and their runtime interpreters really do
# implement what the migration doc describes — confirmed directly in
# lib/hecksagain/bluebook/dsl/query_builder.rb,
# lib/hecksagain/bluebook/dsl/policy_builder.rb,
# lib/hecksagain/runtime/query_interpreter.rb, and
# lib/hecksagain/runtime/policy_interpreter.rb. But writing REAL dispatch-
# level coverage (the same discipline the migration doc's own second
# section names as the reason most of ITS findings were only found by
# dispatching, not validating) surfaced three further, separate, genuine
# runtime gaps nobody had dispatched through yet — found and fixed here,
# meta-validation left on throughout (the every-day default a real
# caller gets ; no example below needs to turn it off any more):
#
# (1) `lib/hecksagain/bluebook/assembly/contracts.rb`'s "Query" and
#     "Policy" contract entries were never extended with the fields their
#     own DSL builders added: `count`/`median_field`/`group_by_field` on
#     Query, `wheres`/`with_literals`/`for_each` on Policy. Every
#     `Hecks.bluebook` load runs `MetaValidator.call`, which dispatches
#     the built IR into the language's OWN self-hosted meta-domain and
#     replaces it with what THAT domain reconstructs — so all six fields
#     survived parsing but silently vanished the moment a bluebook was
#     actually loaded, in every ordinary boot. The exact same shape as
#     `redirects_native`'s own gap (contracts.rb's own comment on the
#     "Command" contract; migration finding #1), just never closed for
#     these six. Fixed by mirroring that precedent: the self-hosted
#     grammar's own "Query"/"Policy" aggregates (lib/hecksagain/language/
#     bluebook/behavior.bluebook, reaction.bluebook) grew the matching
#     fields — plain Declare-time attributes for the three Query scalars,
#     and (since an open map has no value object that can hold it, the
#     same reason `Handler#remembers`/`Dispatch#with_spec` are their own
#     appended rows) a `Pair` value object plus `Where`/`With`/`ForEach`
#     sub-commands for Policy's three. `IR::Policy#for_each_from`/
#     `#for_each_where` and `IR::Policy#to_h` grew to match — see their
#     own comments, and contracts.rb's Policy entry, for exactly how each
#     field reads back. `judge.rb`/`plan.rb`/`readings.rb` needed no
#     changes at all beyond two small open-map row shapers — confirming
#     the same structural finding migration finding #31 already named:
#     the judge is generic over the grammar's own declarations.
#
# (2) `Ports::Query::InMemory#holds?` — the comparator switch a REAL
#     Memory-adapter-backed AGGREGATE query runs through
#     (`Runtime::QueryInterpreter#holds?`'s own comment says as much:
#     "this is the path that actually runs for a memory- or heki-backed
#     aggregate query ; QueryInterpreter#holds? only runs for entity/
#     sub-list queries, or when no adapter implements :query at all") —
#     never had `none_in_state` added to its own copy of the same case
#     statement, only `Runtime::QueryInterpreter#holds?` did. So an
#     ordinary aggregate-level `none_in_state` where-clause against a
#     Memory-backed aggregate (the only kind this whole suite's
#     `InMemoryDomain` ever boots) silently fell to that switch's `else`
#     branch and excluded every row, every time. Fixed by giving
#     `Ports::Query::InMemory` the same comparator, threaded an optional
#     `registry:` (`Runtime::QueryInterpreter#call` already holds one ;
#     `Adapters::Memory#query` now forwards it through `context:`) so the
#     cross-aggregate lookup `none_in_state` needs has something to
#     search — both the entity path (already correct) and the aggregate
#     path are exercised below.
#
# (3) `PolicyInterpreter#deliver_for_each` split `for_each from:` into an
#     aggregate NAME and handed that bare String straight to
#     `QueryInterpreter#call`, which requires a resolved aggregate OBJECT
#     (`QueryInterpreter#declared_query` calls `.query` on whatever it is
#     given) — the resolution step `Dispatcher#query` always does first,
#     via `Dispatcher#resolve_aggregate`, was simply missing. That alone
#     raised a plain `NoMethodError: undefined method 'query' for an
#     instance of String` — but `deliver`'s own `return
#     deliver_for_each(...) if policy.for_each` ran BEFORE `record` (the
#     reaction-log entry `deliver`'s two rescue clauses both call
#     `.merge` on) was assigned, so the SAME method's own defect handling
#     then raised a SECOND, different `NoMethodError: undefined method
#     'merge' for nil` trying to record the first one. Fixed both ways:
#     `deliver_for_each` now resolves the aggregate the same way
#     `Dispatcher#resolve_aggregate` does (mirrored, not reused — that
#     method is private, and this interpreter only ever sees the
#     dispatcher as `@door`), and `record`'s assignment moved above the
#     `for_each` branch so this method's own rescue clauses always have
#     something real to merge onto.
RSpec.describe "query and policy growth: group_by, policy where/for_each, none_in_state" do
  ROOT             = File.expand_path("..", __dir__)
  PERSISTENCE_PORT = File.join(ROOT, "lib/hecksagain/ports/persistence.port")
  EXTRACTION_PORT  = File.join(ROOT, "lib/hecksagain/ports/extraction.port")
  MEMORY_ADAPTER   = File.join(ROOT, "lib/hecksagain/adapters/driven/memory.adapter")
  PRISM_ADAPTER    = File.join(ROOT, "lib/hecksagain/adapters/driven/prism.adapter")

  # Meta-validation stays on throughout — the language's own self-hosted
  # judging pass, the every-day default a real caller gets. No workaround
  # needed any more (see gap (1) above): every construct this file
  # exercises now survives the reload `Hecks.bluebook` always runs.
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["growth-", ".bluebook"])
    file.write(source)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(PERSISTENCE_PORT)
      Kernel.load(EXTRACTION_PORT)
      Kernel.load(MEMORY_ADAPTER)
      Kernel.load(PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    file&.close!
  end

  # ---------------------------------------------------------------------
  # 1. `group_by :field` — finding #10, a third query-aggregation shape
  #    alongside `count`/`median`: partitions the where-filtered set by
  #    a field's value and tallies each partition, one row per distinct
  #    value, ordered by count descending then by the value itself.
  # ---------------------------------------------------------------------
  describe "a query's own group_by" do
    GROUP_BY_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "ScoreboardGrowth" do
        aggregate "Submission" do
          identified_by { id.value }

          value_object "SubmissionId" do
            attribute :value, String
          end

          attribute :id,     SubmissionId
          attribute :player, String
          attribute :points, Integer

          command "Submit" do
            attribute :id,     SubmissionId
            attribute :player, String
            attribute :points, Integer
            emits "Submitted"
          end

          query "PerPlayer" do
            group_by :player
          end
        end
      end
    BLUEBOOK

    def boot_scoreboard
      boot(GROUP_BY_SOURCE, "ScoreboardGrowth") do
        ::ScoreboardGrowth::Submission.persisted_by("Memory")
      end
    end

    it "tallies rows into one row per distinct group value, ordered by count then value" do
      runtime = boot_scoreboard
      runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s1" }, player: "Ada",   points: 10)
      runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s2" }, player: "Ada",   points: 20)
      runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s3" }, player: "Grace", points: 5)
      runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s4" }, player: "Ada",   points: 1)

      rows = runtime.query("ScoreboardGrowth::Submission.PerPlayer")

      # Ada submitted 3 times, Grace once — descending by count, Ada first.
      expect(rows).to eq([{ player: "Ada", count: 3 }, { player: "Grace", count: 1 }])
    end

    it "breaks a tie in count by the group value itself, so the order is deterministic" do
      runtime = boot_scoreboard
      runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s1" }, player: "Zed", points: 1)
      runtime.dispatch("ScoreboardGrowth::Submission.Submit", id: { value: "s2" }, player: "Amy", points: 1)

      rows = runtime.query("ScoreboardGrowth::Submission.PerPlayer")

      expect(rows).to eq([{ player: "Amy", count: 1 }, { player: "Zed", count: 1 }])
    end
  end

  # ---------------------------------------------------------------------
  # 2 & 3. Policy `where field: value` (finding #11) and `for_each
  #    from:, where:` + `from_event` (finding #12).
  # ---------------------------------------------------------------------
  describe "a policy's own where clause" do
    POLICY_WHERE_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "AlarmGrowth" do
        aggregate "Sensor" do
          identified_by { id.value }

          value_object "SensorId" do
            attribute :value, String
          end

          attribute :id,    SensorId
          attribute :level, String

          command "Report" do
            attribute :id,    SensorId
            attribute :level, String
            emits "Reported"
          end

          command "Alert" do
            reference_to Sensor
            attribute :level, String, optional: true
            then_set :level, to: "alerted"
          end

          policy "AlertOnCritical" do
            on "Reported"
            where level: "critical"
            trigger "Sensor.Alert"
          end
        end
      end
    BLUEBOOK

    def boot_alarm
      boot(POLICY_WHERE_SOURCE, "AlarmGrowth") do
        ::AlarmGrowth::Sensor.persisted_by("Memory")
      end
    end

    it "fires the trigger when the triggering event's own payload matches the where clause" do
      runtime = boot_alarm
      runtime.dispatch("AlarmGrowth::Sensor.Report", id: { value: "s1" }, level: "critical")

      expect(runtime.reactions).to contain_exactly(
        hash_including(policy: "AlertOnCritical", on: "Reported",
                       trigger: "AlarmGrowth::Sensor.Alert", delivered: true)
      )
      expect(AlarmGrowth::Sensor.find("s1").level.to_h).to eq(value: "alerted")
    end

    it "does not fire — and is not a refusal — when the payload doesn't match" do
      runtime = boot_alarm
      runtime.dispatch("AlarmGrowth::Sensor.Report", id: { value: "s2" }, level: "normal")

      expect(runtime.reactions).to be_empty
      expect(AlarmGrowth::Sensor.find("s2").level.to_h).to eq(value: "normal")
    end
  end

  describe "a policy's own for_each fan-out" do
    FOR_EACH_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "FanoutGrowth" do
        aggregate "Board" do
          identified_by { id.value }

          value_object "BoardId" do
            attribute :value, String
          end

          attribute :id, BoardId

          command "Open" do
            attribute :id, BoardId
            emits "Opened"
          end
        end

        aggregate "Ticket" do
          identified_by { id.value }

          value_object "TicketId" do
            attribute :value, String
          end

          attribute :id,       TicketId
          attribute :board_id, String
          attribute :status,   String, default: "open"

          command "Create" do
            attribute :id,       TicketId
            attribute :board_id, String
            emits "Created"
          end

          command "Ping" do
            reference_to Ticket
            then_set :status, to: "pinged"
          end

          query "ForBoard" do
            attribute :board_id, String
            where board_id: :board_id
          end
        end

        policy "PingTicketsOnOpen" do
          on "Opened"
          for_each from: "Ticket.ForBoard", where: { board_id: from_event(:id) }
          trigger "Ticket.Ping"
        end
      end
    BLUEBOOK

    # The DSL side alone — `PolicyBuilder.build` — needs no boot at all:
    # this proves the BUILDER (finding #12's own DSL half) parses
    # `for_each`/`from_event` into the shape
    # `PolicyInterpreter#deliver_for_each` reads, independent of the real
    # dispatch the example below drives through that same shape.
    it "parses for_each + from_event into the fan-out shape the interpreter reads" do
      policy = Hecksagain::Bluebook::DSL::PolicyBuilder.build("PingTicketsOnOpen") do
        on "Opened"
        for_each from: "Ticket.ForBoard", where: { board_id: from_event(:id) }
        trigger "Ticket.Ping"
      end

      expect(policy.for_each).to eq(from: "Ticket.ForBoard", where: { board_id: :id })
    end

    # A REAL dispatch, not just a parse — the discipline
    # docs/hecks-migration-findings.md's own "the discipline that found
    # these" section names as the reason most of its 36 findings were
    # findable at all. It found a 37th here: gap (3) in this file's own
    # header comment, now fixed — `deliver_for_each` resolves `from:`'s
    # aggregate name properly before querying it, so the fan-out actually
    # runs: one `Ticket.Ping` dispatch per row `Ticket.ForBoard` returns,
    # each `for_each`'s own `where:` correctly threading `from_event(:id)`
    # — the OPENING board's own id, from `Opened`'s payload — into the
    # query, so only tickets on THAT board are touched.
    it "dispatches once per row the named query returns, threading the triggering event into each" do
      runtime = boot(FOR_EACH_SOURCE, "FanoutGrowth") do
        ::FanoutGrowth::Board.persisted_by("Memory")
        ::FanoutGrowth::Ticket.persisted_by("Memory")
      end
      runtime.dispatch("FanoutGrowth::Ticket.Create", id: { value: "t1" }, board_id: "b1")
      runtime.dispatch("FanoutGrowth::Ticket.Create", id: { value: "t2" }, board_id: "b1")
      # A THIRD ticket, on a DIFFERENT board — proves the fan-out is
      # SCOPED by for_each's own where:, not every ticket in existence.
      runtime.dispatch("FanoutGrowth::Ticket.Create", id: { value: "t3" }, board_id: "b2")

      runtime.dispatch("FanoutGrowth::Board.Open", id: { value: "b1" })

      expect(runtime.reactions).to contain_exactly(
        hash_including(policy: "PingTicketsOnOpen", on: "Opened",
                       trigger: "FanoutGrowth::Ticket.Ping", for_row: "t1", delivered: true),
        hash_including(policy: "PingTicketsOnOpen", on: "Opened",
                       trigger: "FanoutGrowth::Ticket.Ping", for_row: "t2", delivered: true)
      )
      expect(FanoutGrowth::Ticket.find("t1").status.to_h).to eq(value: "pinged")
      expect(FanoutGrowth::Ticket.find("t2").status.to_h).to eq(value: "pinged")
      expect(FanoutGrowth::Ticket.find("t3").status.to_h).to eq(value: "open")
    end
  end

  # ---------------------------------------------------------------------
  # 4. `none_in_state` (finding #13) — a cross-aggregate anti-join
  #    comparator: `where field: { none_in_state: "Aggregate:state" }`
  #    holds when the record `field`'s value points at is NOT currently
  #    in that state (including when it points at no record at all).
  #    Exercised on an ENTITY query — see gap (2) in this file's own
  #    header comment for exactly why the equivalent AGGREGATE-level
  #    query silently returns nothing today.
  # ---------------------------------------------------------------------
  describe "none_in_state, a cross-aggregate anti-join" do
    NONE_IN_STATE_SOURCE = <<~BLUEBOOK
      Hecks.bluebook "AntiJoinGrowth" do
        aggregate "Claim" do
          identified_by { id.value }

          value_object "ClaimId" do
            attribute :value, String
          end

          attribute :id,    ClaimId
          attribute :state, String, default: "held"

          command "File" do
            attribute :id, ClaimId
            emits "Filed"
          end

          command "Release" do
            reference_to Claim
            then_set :state, to: "released"
          end
        end

        aggregate "Board" do
          identified_by { id.value }

          value_object "BoardId" do
            attribute :value, String
          end

          attribute :id,               BoardId
          attribute :assignments,      list_of(Assignment)
          # A SCALAR twin of Assignment's own `claim_id` — Board's own
          # field, not an entity's, so `Board.Flagged` below exercises the
          # AGGREGATE-level Memory query path (`Ports::Query::InMemory#
          # holds?`) rather than the entity path `Assignment.Unclaimed`
          # already does (`Runtime::QueryInterpreter#holds?`).
          attribute :flagged_claim_id, String, optional: true

          entity "Assignment" do
            identified_by { claim_id.value }

            attribute :claim_id, String

            query "Unclaimed" do
              where claim_id: { none_in_state: "Claim:held" }
            end
          end

          command "Open" do
            attribute :id, BoardId
            emits "Opened"
          end

          command "Assign" do
            reference_to Board
            attribute :claim_id, String
            then_set :assignments, append: { claim_id: :claim_id }
            emits "Assigned"
          end

          command "Flag" do
            reference_to Board
            attribute :claim_id, String
            then_set :flagged_claim_id, to: :claim_id
            emits "Flagged"
          end

          query "Flagged" do
            where flagged_claim_id: { none_in_state: "Claim:held" }
          end
        end
      end
    BLUEBOOK

    def boot_anti_join
      boot(NONE_IN_STATE_SOURCE, "AntiJoinGrowth") do
        ::AntiJoinGrowth::Claim.persisted_by("Memory")
        ::AntiJoinGrowth::Board.persisted_by("Memory")
      end
    end

    it "excludes an assignment whose claim IS in the named state, and keeps the rest" do
      runtime = boot_anti_join
      runtime.dispatch("AntiJoinGrowth::Claim.File", id: { value: "c1" })  # stays "held"
      runtime.dispatch("AntiJoinGrowth::Claim.File", id: { value: "c2" })
      runtime.dispatch("AntiJoinGrowth::Claim.Release", id: "c2")          # no longer "held"

      runtime.dispatch("AntiJoinGrowth::Board.Open", id: { value: "b1" })
      runtime.dispatch("AntiJoinGrowth::Board.Assign", id: "b1", claim_id: "c1")
      runtime.dispatch("AntiJoinGrowth::Board.Assign", id: "b1", claim_id: "c2")
      # A claim that was never filed at all — "no record in that state" reads
      # the same as "a record, but not in that state" (Runtime::
      # QueryInterpreter#none_in_state?'s own `return true unless record`).
      runtime.dispatch("AntiJoinGrowth::Board.Assign", id: "b1", claim_id: "nonexistent")

      rows = runtime.query("AntiJoinGrowth::Board.Assignment.Unclaimed")

      expect(rows.map { |row| row[:claim_id] }).to contain_exactly("c2", "nonexistent")
    end

    # Gap (2) in this file's own header comment, now fixed — the SAME
    # anti-join, on an ordinary AGGREGATE-level Memory query
    # (`Board.Flagged`) rather than the entity path the example above
    # exercises. Before the fix this returned nothing, every time,
    # regardless of any board's own state.
    it "excludes a board whose flagged claim IS in the named state, on the aggregate query path" do
      runtime = boot_anti_join
      runtime.dispatch("AntiJoinGrowth::Claim.File", id: { value: "c1" })  # stays "held"
      runtime.dispatch("AntiJoinGrowth::Claim.File", id: { value: "c2" })
      runtime.dispatch("AntiJoinGrowth::Claim.Release", id: "c2")          # no longer "held"

      runtime.dispatch("AntiJoinGrowth::Board.Open", id: { value: "b1" })
      runtime.dispatch("AntiJoinGrowth::Board.Flag", id: "b1", claim_id: "c1")
      runtime.dispatch("AntiJoinGrowth::Board.Open", id: { value: "b2" })
      runtime.dispatch("AntiJoinGrowth::Board.Flag", id: "b2", claim_id: "c2")
      runtime.dispatch("AntiJoinGrowth::Board.Open", id: { value: "b3" })
      runtime.dispatch("AntiJoinGrowth::Board.Flag", id: "b3", claim_id: "nonexistent")

      rows = runtime.query("AntiJoinGrowth::Board.Flagged")

      expect(rows.map { |row| row[:id] }).to contain_exactly("b2", "b3")
    end
  end
end
