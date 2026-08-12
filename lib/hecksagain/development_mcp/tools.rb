require "json"

module Hecksagain
  module DevelopmentMcp
    # THE TOOL TABLE.
    #
    # ONE TOOL PER STEP OF `qa/SOP.md`, not one tool per command. There is
    # deliberately no `qc_dispatch(verb, args)` general-purpose door: an
    # agent handed one would have to know the verb spelling, the value-object
    # wrapping (`{value: "..."}`), which arguments are minted by the runtime
    # and which it must supply — all of which is exactly the friction that
    # keeps a QA agent editing markdown instead. Each tool below takes flat
    # strings and mints what can be minted.
    #
    # THE DESCRIPTIONS ARE THE DOCUMENTATION, and they are written for a
    # reader who has not opened the bluebook. Where a tool will refuse, the
    # description says so and says what to do first — an agent that learns
    # the workflow from `tools/list` never has to hit the refusal to find
    # out the rule exists.
    #
    # `qc_query` IS THE ONE ESCAPE HATCH, and it is read-only. Every query
    # in the chapter is reachable through it by name, so a question nobody
    # anticipated does not need a new tool; nothing that WRITES is reachable
    # that way, so the workflow above stays the only way in.
    module Tools
      module_function

      def descriptors
        TABLE.map do |name, spec|
          {
            "name"        => name,
            "description" => spec[:description],
            "inputSchema" => {
              "type"       => "object",
              "properties" => spec[:properties],
              "required"   => spec[:required] || []
            }
          }
        end
      end

      def call(ledger, name, args)
        spec = TABLE[name] or raise ArgumentError, "no such tool #{name.inspect} — see tools/list"
        missing = (spec[:required] || []) - args.keys.map(&:to_s)
        raise ArgumentError, "missing required argument(s): #{missing.join(', ')}" unless missing.empty?

        spec[:run].call(ledger, args)
      end

      def text(prop, description) = [prop, { "type" => "string", "description" => description }]
      def number(prop, description) = [prop, { "type" => "integer", "description" => description }]

      def pretty(value) = JSON.pretty_generate(value)

      # Rows come back full of value-object wrappers. A dashboard an agent
      # reads at a glance wants the handle and the state, not the shape.
      def brief(rows)
        rows.map do |row|
          {
            id:     row.dig(:reference, :value) || row[:id] || row.dig(:sequence, :value),
            status: row[:status] || row[:outcome],
            what:   row.dig(:title, :value) || row.dig(:subject, :value) ||
                    row.dig(:approach, :value) || row.dig(:engineer, :value)
          }.compact
        end
      end

      TABLE = {
        # ── reading ────────────────────────────────────────────────────
        "qc_status" => {
          description: "The QA dashboard. Every list it returns is one that should be empty or short: " \
                       "bugs nobody reproduced, remedies nobody ruled on, filings the tracker never " \
                       "answered, tickets resting on a bug that is already fixed. Start a session here.",
          properties: {},
          run: ->(ledger, _args) { pretty(ledger.status.reject { |_, v| v.empty? }.transform_values { |v| brief(v) }) }
        },

        "qc_bug" => {
          description: "Everything known about one bug: the record, every fix attempted against it, and " \
                       "every ticket raised about it. The read to do before deciding what to do next.",
          properties: Hash[[text("reference", "the bug reference, e.g. BUG#4")]],
          required: %w[reference],
          run: ->(ledger, args) { pretty(ledger.dossier(args[:reference])) }
        },

        "qc_coverage" => {
          description: "How much attention one domain has actually had — tests written, which adversarial " \
                       "categories were applied, bugs found, bugs still open. An empty answer names an " \
                       "untested domain, which is the most useful answer it gives.",
          properties: Hash[[text("domain", "the domain name, e.g. Pizzas or Compliance")]],
          required: %w[domain],
          run: ->(ledger, args) { pretty(ledger.coverage(domain: args[:domain])) }
        },

        "qc_report" => {
          description: "Render the daily report for a session as markdown, from the ledger rather than " \
                       "from memory. Write it to qa/reports/YYYY-MM-DD.md — that file is the OUTPUT of " \
                       "the record, not its source.",
          properties: Hash[[text("session", "the session reference, e.g. QA-2026-08-11")]],
          required: %w[session],
          run: ->(ledger, args) { ledger.report(session: args[:session]) }
        },

        "qc_query" => {
          description: "Run any query the chapter declares, by name — the read-only escape hatch for a " \
                       "question no other tool covers. Names look like 'Bug.Paused', 'Bug.BySeverity', " \
                       "'Session.TestCase.InCategory', 'Remedy.Abandoned', 'Ticket.Submitting'. " \
                       "Arguments, when a query takes one, are plain strings.",
          properties: {
            "name" => { "type" => "string", "description" => "e.g. Bug.BySeverity" },
            "argument" => { "type" => "string", "description" => "the query's single argument, if it takes one" },
            "argument_name" => { "type" => "string", "description" => "that argument's name, e.g. severity" }
          },
          required: %w[name],
          run: lambda { |ledger, args|
            params = args[:argument] ? { args.fetch(:argument_name).to_sym => { value: args[:argument] } } : {}
            pretty(ledger.query(args[:name], **params))
          }
        },

        # ── the session ────────────────────────────────────────────────
        "qc_start_session" => {
          description: "Begin a QA sitting. Returns the reference every later call needs. One per " \
                       "sitting — a session records who ran it, and completing one that tested nothing " \
                       "is refused.",
          properties: Hash[[text("engineer", "who is running this session, e.g. 'Claude QA'")]],
          required: %w[engineer],
          run: ->(ledger, args) { "session #{ledger.start_session(engineer: args[:engineer])} started" }
        },

        "qc_write_test" => {
          description: "Record one adversarial check BEFORE running it, carrying only what you expect to " \
                       "happen. This is the rule the whole ledger stands on: an expectation written after " \
                       "the outcome is an expectation fitted to the outcome. Returns the test number. " \
                       "Report the result separately with qc_settle_test.",
          properties: Hash[[
            text("session", "the session reference"),
            text("domain", "the domain under test, e.g. Pizzas"),
            text("category", "the adversarial category: boundary, empty, state, mutation, identity, " \
                             "coercion, rapid, special_chars — or a new one you are naming"),
            text("subject", "what is being attacked, e.g. Pizzas::Order.CreatePizza"),
            text("expectation", "what should happen"),
            text("location", "how to re-run it, e.g. 'rspec spec/qa_bugs_spec.rb -e \"BUG#7\"'")
          ]],
          required: %w[session domain category subject expectation location],
          run: lambda { |ledger, args|
            n = ledger.write_test(session: args[:session], domain: args[:domain], category: args[:category],
                                  subject: args[:subject], expectation: args[:expectation],
                                  location: args[:location])
            "test ##{n} written"
          }
        },

        "qc_settle_test" => {
          description: "Say what actually came back. 'inconclusive' is a real answer and not a hedge — it " \
                       "is the state where something looked wrong and the run did not settle it, which is " \
                       "where three entries in qa/FINDINGS.md sat for a week without a word for it.",
          properties: Hash[[
            text("session", "the session reference"),
            number("sequence", "the test number qc_write_test returned"),
            text("outcome", "pass, fail, or inconclusive"),
            text("observation", "what actually happened")
          ]],
          required: %w[session sequence outcome observation],
          run: lambda { |ledger, args|
            ledger.settle_test(session: args[:session], sequence: args[:sequence].to_i,
                               outcome: args[:outcome], observation: args[:observation])
            "test ##{args[:sequence]} settled: #{args[:outcome]}"
          }
        },

        "qc_rerun_test" => {
          description: "Put a settled test back in play against a system that has since changed. The same " \
                       "test, not a new one — which is what makes it a regression check.",
          properties: Hash[[text("session", "the session reference"), number("sequence", "the test number")]],
          required: %w[session sequence],
          run: lambda { |ledger, args|
            ledger.rerun_test(session: args[:session], sequence: args[:sequence].to_i)
            "test ##{args[:sequence]} is open again — settle it with qc_settle_test"
          }
        },

        "qc_graduate_test" => {
          description: "Move a PASSING test out of spec/qa_bugs_spec.rb and into the real suite, dropping " \
                       "its qa: true tag. Refused for a failing test — graduating one of those is how a " \
                       "suite stops being trusted. Check qc_query name='Session.TestCase.ReadyToGraduate'.",
          properties: Hash[[
            text("session", "the session reference"),
            number("sequence", "the test number"),
            text("location", "where it lives now, e.g. spec/pizzas_spec.rb")
          ]],
          required: %w[session sequence location],
          run: lambda { |ledger, args|
            ledger.graduate_test(session: args[:session], sequence: args[:sequence].to_i,
                                 location: args[:location])
            "test ##{args[:sequence]} graduated to #{args[:location]}"
          }
        },

        "qc_complete_session" => {
          description: "End a session and say what it learned. Refused if the session tested nothing, and " \
                       "refused if the notes are under 40 characters — a session concluded with 'done' " \
                       "has no durable output. Check Session.TestCase.Unsettled first; rows there mean " \
                       "you are concluding early.",
          properties: Hash[[
            text("session", "the session reference"),
            text("notes", "what was learned — a finding, not a word")
          ]],
          required: %w[session notes],
          run: lambda { |ledger, args|
            ledger.complete_session(session: args[:session], notes: args[:notes])
            "session #{args[:session]} completed"
          }
        },

        # ── the bug ────────────────────────────────────────────────────
        "qc_discover" => {
          description: "Log that something is wrong, before knowing what. Returns the bug reference. " \
                       "It lands in 'found', from which the ONLY move is qc_reproduce — nothing can be " \
                       "investigated, fixed, paused, dismissed or filed until the bug happens on demand.",
          properties: Hash[[
            text("session", "the session that found it"),
            text("domain", "where it was found, e.g. Pizzas"),
            text("title", "a one-line name for it"),
            text("symptom", "what actually happened"),
            text("expectation", "what should have happened"),
            text("severity", "high, medium or low — nothing else is accepted"),
            text("reference", "optional: an existing reference such as BUG#4, when importing"),
            number("sequence", "optional: an existing number, when importing")
          ]],
          required: %w[session domain title symptom expectation severity],
          run: lambda { |ledger, args|
            ref = ledger.discover(session: args[:session], domain: args[:domain], title: args[:title],
                                  symptom: args[:symptom], expectation: args[:expectation],
                                  severity: args[:severity], reference: args[:reference],
                                  sequence: args[:sequence]&.to_i)
            "#{ref} logged — reproduce it next with qc_reproduce"
          }
        },

        "qc_cite" => {
          description: "Name another test case this bug was seen in. Worth doing when two tests in " \
                       "different categories turn out to be the same fault — the pair is the evidence.",
          properties: Hash[[text("bug", "the bug reference"), number("test_case", "the test number")]],
          required: %w[bug test_case],
          run: lambda { |ledger, args|
            ledger.cite(bug: args[:bug], test_case: args[:test_case].to_i)
            "test ##{args[:test_case]} cited against #{args[:bug]}"
          }
        },

        "qc_reproduce" => {
          description: "Show the bug happening on demand, which is what makes it a bug. Requires a way " \
                       "to re-run it — a demonstration nobody can repeat is a claim. This is qa/SOP.md " \
                       "§4.0 and it is the gate everything else stands on.",
          properties: Hash[[
            text("bug", "the bug reference"),
            text("how", "how to re-run it, e.g. 'rspec spec/qa_bugs_spec.rb -e \"BUG#7\"'")
          ]],
          required: %w[bug how],
          run: lambda { |ledger, args|
            ledger.reproduce(bug: args[:bug], how: args[:how])
            "#{args[:bug]} reproduced — investigate it next"
          }
        },

        "qc_investigate" => {
          description: "Name the code that is wrong and say why. Requires a file (and ideally a line): " \
                       "'investigating' is not a claim to understand the bug, it is the site the claim " \
                       "can be checked against. Refused before the bug is reproduced.",
          properties: Hash[[
            text("bug", "the bug reference"),
            text("site", "where it lives, e.g. lib/hecksagain/runtime/value/coercion.rb:118"),
            text("cause", "why that code is wrong")
          ]],
          required: %w[bug site cause],
          run: lambda { |ledger, args|
            ledger.investigate(bug: args[:bug], site: args[:site], cause: args[:cause])
            "#{args[:bug]} investigated — try a fix with qc_attempt before considering a ticket"
          }
        },

        "qc_fix" => {
          description: "Record the commit that makes the bug stop happening. The commit is REQUIRED and " \
                       "must be a real sha (7-40 hex characters) — a fix that lives in a working tree is " \
                       "not a fix. Refused before the bug is investigated. Run the full suite, then " \
                       "qc_verify.",
          properties: Hash[[text("bug", "the bug reference"), text("commit", "the commit sha, e.g. 63750a3")]],
          required: %w[bug commit],
          run: lambda { |ledger, args|
            ledger.fix(bug: args[:bug], commit: args[:commit])
            "#{args[:bug]} fixed at #{args[:commit]} — run the full suite, then qc_verify"
          }
        },

        "qc_verify" => {
          description: "Record that the FULL suite passed against the fix (qa/SOP.md §5.4 — " \
                       "'bundle exec rspec --order random', not just the domain's own file). This is the " \
                       "only edge into 'verified' and it comes only from 'fixed'.",
          properties: Hash[[text("bug", "the bug reference")]],
          required: %w[bug],
          run: lambda { |ledger, args|
            ledger.verify(bug: args[:bug])
            "#{args[:bug]} verified"
          }
        },

        "qc_pause_bug" => {
          description: "Stop on a bug that is real and too large to fix here — qa/FINDINGS.md's PAUSED. " \
                       "The reason is required and becomes the 'Why Not Fixed' section of any ticket " \
                       "that follows, so write it as if a stranger will read it.",
          properties: Hash[[text("bug", "the bug reference"), text("reason", "where the work stopped, and why")]],
          required: %w[bug reason],
          run: lambda { |ledger, args|
            ledger.pause_bug(bug: args[:bug], reason: args[:reason])
            "#{args[:bug]} paused"
          }
        },

        "qc_dismiss" => {
          description: "Close out a REPRODUCED bug that turned out to be correct behaviour — " \
                       "qa/FINDINGS.md's 'LIKELY NOT A BUG'. Deliberately unreachable from 'found': " \
                       "'it's probably fine', said about something nobody ever reproduced, is exactly " \
                       "how a real bug gets closed.",
          properties: Hash[[text("bug", "the bug reference"), text("reason", "why it is correct behaviour")]],
          required: %w[bug reason],
          run: lambda { |ledger, args|
            ledger.dismiss(bug: args[:bug], reason: args[:reason])
            "#{args[:bug]} dismissed"
          }
        },

        "qc_regress" => {
          description: "Put a fixed or verified bug back in play because the fix stopped holding. It " \
                       "keeps its evidence and history and returns to 'reproduced' — the investigation " \
                       "is exactly what a regression disproves, so it has to be done again.",
          properties: Hash[[text("bug", "the bug reference")]],
          required: %w[bug],
          run: ->(ledger, args) { ledger.regress(bug: args[:bug]); "#{args[:bug]} regressed" }
        },

        "qc_block" => {
          description: "Record that another bug has to be fixed first — qa/FINDINGS.md #3's 'Blocked on " \
                       "#2'. Every row in Bug.Blocked is work that would be wasted if somebody picked it " \
                       "up. Pass blocked_by='none' to clear it.",
          properties: Hash[[
            text("bug", "the bug reference"),
            text("blocked_by", "the blocking bug's reference, or 'none' to clear")
          ]],
          required: %w[bug blocked_by],
          run: lambda { |ledger, args|
            if args[:blocked_by].to_s == "none"
              ledger.unblock(bug: args[:bug])
              "#{args[:bug]} is no longer blocked"
            else
              ledger.block(bug: args[:bug], blocked_by: args[:blocked_by])
              "#{args[:bug]} is blocked by #{args[:blocked_by]}"
            end
          }
        },

        # ── the fix attempt ────────────────────────────────────────────
        "qc_attempt" => {
          description: "Start a fix, saying what you are trying BEFORE trying it. Returns the remedy " \
                       "reference. This is qa/SOP.md's 'fix first, file second' made mechanical: a " \
                       "ticket cannot be drafted without pointing at one of these. Even an architectural " \
                       "bug you will not attempt deserves one — record the approach and abandon it in " \
                       "the same minute; that IS the §5.3 documentation.",
          properties: Hash[[
            text("bug", "the bug reference"),
            text("engineer", "who is attempting it — need not be who found it"),
            text("approach", "what is being tried")
          ]],
          required: %w[bug engineer approach],
          run: lambda { |ledger, args|
            ref = ledger.attempt(bug: args[:bug], engineer: args[:engineer], approach: args[:approach])
            "#{ref} attempted against #{args[:bug]}"
          }
        },

        "qc_touch" => {
          description: "Record one place the fix changed. Only while the attempt is still open — a " \
                       "remedy that grows a file after it landed is not the remedy that landed.",
          properties: Hash[[
            text("remedy", "the remedy reference, e.g. REM-1"),
            text("path", "the file touched"),
            text("note", "what changed there")
          ]],
          required: %w[remedy path note],
          run: lambda { |ledger, args|
            ledger.touch(remedy: args[:remedy], path: args[:path], note: args[:note])
            "#{args[:remedy]} touched #{args[:path]}"
          }
        },

        "qc_settle_remedy" => {
          description: "Say whether the attempt worked. 'landed' means the approach worked (record the " \
                       "commit separately with qc_fix — one commit often closes several bugs). " \
                       "'abandoned' requires a reason, and that reason is the most reused sentence in " \
                       "the ledger: it becomes the ticket's 'Why Not Fixed'. Leaving an attempt unsettled " \
                       "puts it in Remedy.Unresolved, a list that must always be empty.",
          properties: Hash[[
            text("remedy", "the remedy reference"),
            text("outcome", "landed or abandoned"),
            text("reason", "required when abandoning: exactly where it ran out")
          ]],
          required: %w[remedy outcome],
          run: lambda { |ledger, args|
            case args[:outcome].to_s
            when "landed"
              ledger.land(remedy: args[:remedy])
              "#{args[:remedy]} landed — record the commit with qc_fix"
            when "abandoned"
              reason = args[:reason] or raise ArgumentError, "abandoning an attempt requires a reason"
              ledger.abandon(remedy: args[:remedy], reason: reason)
              "#{args[:remedy]} abandoned"
            else
              raise ArgumentError, "outcome must be landed or abandoned"
            end
          }
        },

        # ── the outside world ──────────────────────────────────────────
        "qc_draft_ticket" => {
          description: "Compose an issue for the outside world. Requires a remedy reference, and that " \
                       "requirement IS the 'fix first, file second' rule — a ticket that cannot name an " \
                       "attempt cannot be drafted at all. Leave title and body out and both are composed " \
                       "from the record in qa/SOP.md §6.1's format. Nothing is sent: this only drafts.",
          properties: Hash[[
            text("bug", "the bug reference"),
            text("remedy", "the attempt this ticket is written out of"),
            text("repository", "owner/name, e.g. chrisyoung/hecksagain"),
            text("title", "optional — composed from the bug when omitted"),
            text("body", "optional — composed from the bug and the remedy when omitted")
          ]],
          required: %w[bug remedy repository],
          run: lambda { |ledger, args|
            ref = ledger.draft_ticket(bug: args[:bug], remedy: args[:remedy],
                                      repository: args[:repository], title: args[:title], body: args[:body])
            "#{ref} drafted — read it with qc_query name='Ticket.All' before qc_file_ticket"
          }
        },

        "qc_file_ticket" => {
          description: "SEND the ticket to GitHub via the gh CLI. This is public and not undoable — a " \
                       "filed issue can be closed but never unsaid. Requires confirm='yes'. Check " \
                       "Ticket.RestingOnUnreproduced and Ticket.RestingOnLiveRemedy first; a row in " \
                       "either means this filing should not go out yet.",
          properties: Hash[[
            text("ticket", "the ticket reference, e.g. TK-1"),
            text("confirm", "must be exactly 'yes' — this publishes to a public tracker")
          ]],
          required: %w[ticket confirm],
          run: lambda { |ledger, args|
            unless args[:confirm].to_s == "yes"
              raise ArgumentError, "filing publishes to a public tracker — pass confirm='yes' to proceed"
            end

            result = ledger.file_ticket(ticket: args[:ticket])
            result[:filed] ? "filed as ##{result[:number]} — #{result[:url]}"
                           : "the tracker refused it: #{result[:refusal]}"
          }
        },

        "qc_close_ticket" => {
          description: "Record what became of an issue the tracker is holding. Every row in " \
                       "Ticket.RestingOnVerified is a stranger reading a public issue about a bug that " \
                       "no longer exists — this is the debt that clears it. Note this records the close " \
                       "in the ledger; close it on GitHub too.",
          properties: Hash[[
            text("ticket", "the ticket reference"),
            text("resolution", "what became of it")
          ]],
          required: %w[ticket resolution],
          run: lambda { |ledger, args|
            ledger.close_ticket(ticket: args[:ticket], resolution: args[:resolution])
            "#{args[:ticket]} closed"
          }
        }
      }.freeze
    end
  end
end
