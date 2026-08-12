require "json"
require "open3"
require_relative "../../hecksagain"
require_relative "../facade/json_door"

module Hecksagain
  module QualityControl
    # THE QA LEDGER, IN PROCESS.
    #
    # `qa/bluebook/quality_control.bluebook` is the model; this is the one
    # place that holds a booted runtime of it and knows the handful of things
    # a model deliberately does not: how to mint the next reference, what a
    # GitHub issue body should say, and how to shell out to `gh`.
    #
    # WHY A LIBRARY AND NOT A SCRIPT. `bin/quality_control` and the MCP
    # server both need every one of these operations, and the last time this
    # repository had a tool whose logic lived in `bin/` the spec suite paid
    # for it by spawning 51 subprocesses per example (see
    # `lib/hecksagain/interview/shape.rb`, extracted for exactly that
    # reason). Both front ends call in-process; the spec does too.
    #
    # EVERY REFUSAL PROPAGATES. Nothing here rescues a
    # `Runtime::DOMAIN_REFUSALS` member and turns it into a return value: the
    # refusal wording — "Investigate refused — status is \"found\", and
    # Investigate moves it only from \"reproduced\"" — is the most useful
    # thing this tool can hand an agent, and a caller that swallowed it
    # would be replacing a sentence written by the language with one written
    # here. The MCP server turns them into tool errors at the boundary,
    # message intact.
    class Ledger
      DOMAIN = "QualityControl".freeze

      # THIS REPOSITORY, FOUND FROM THE CODE RATHER THAN FROM THE WORKING
      # DIRECTORY. An MCP server is started by an editor, with a cwd nobody
      # chose; `__dir__` is where this file actually is. `HECKSAGAIN_ROOT`
      # overrides it for a checkout in an unusual place.
      def self.root
        ENV.fetch("HECKSAGAIN_ROOT") { File.expand_path("../../..", __dir__) }
      end

      def self.open(root: self.root) = new(root)

      attr_reader :root, :runtime

      def initialize(root)
        @root    = root
        @runtime = Hecks.boot(File.join(root, "qa"), install_facade: false)
      end

      # ── sessions ───────────────────────────────────────────────────────

      def start_session(engineer:, reference: nil)
        reference ||= mint_session_reference
        dispatch("Session.Start", reference: v(reference), engineer: v(engineer))
        reference
      end

      # Returns the sequence the runtime minted, which is what every later
      # verb against this test case needs and which no caller can guess.
      def write_test(session:, domain:, category:, subject:, expectation:, location:)
        handle = dispatch("Session.Test", id: session,
                                          domain: v(domain), category: v(category),
                                          subject: v(subject), expectation: v(expectation),
                                          location: v(location))
        handle.state[:tested][:value]
      end

      # `pass` / `fail` / `inconclusive` — one verb, because a caller that
      # has just run a test has one thing to say and three words for it.
      def settle_test(session:, sequence:, outcome:, observation:)
        verb = { "pass" => "Pass", "fail" => "Fail", "inconclusive" => "Inconclusive" }
               .fetch(outcome.to_s) { raise ArgumentError, "outcome must be pass, fail or inconclusive" }
        dispatch("Session.TestCase.#{verb}", id: session, sequence: v(sequence, :value),
                                             observation: v(observation))
      end

      def rerun_test(session:, sequence:)
        dispatch("Session.TestCase.Rerun", id: session, sequence: v(sequence, :value))
      end

      def graduate_test(session:, sequence:, location:)
        dispatch("Session.TestCase.Graduate", id: session, sequence: v(sequence, :value),
                                              location: v(location))
      end

      def complete_session(session:, notes:)
        dispatch("Session.Complete", id: session, notes: v(notes))
      end

      def pause_session(session:)  = dispatch("Session.Pause", id: session)
      def resume_session(session:) = dispatch("Session.Resume", id: session)

      # ── bugs ───────────────────────────────────────────────────────────

      # `sequence:` and `reference:` are both overridable so an existing
      # practice can be imported rather than restarted — `qa/FINDINGS.md`
      # already numbers ten bugs, and a ledger that renumbered them would
      # break every reference in every commit message that ever mentioned
      # one. Left alone, both are minted.
      def discover(session:, domain:, title:, symptom:, expectation:, severity:,
                   reference: nil, sequence: nil)
        sequence  ||= next_sequence("Bug")
        reference ||= "BUG##{sequence}"
        dispatch("Bug.Discover", session_id: session,
                                 reference: v(reference), sequence: v(sequence, :value),
                                 domain: v(domain), title: v(title), symptom: v(symptom),
                                 expectation: v(expectation), severity: v(severity))
        reference
      end

      def cite(bug:, test_case:)      = dispatch("Bug.Cite", id: bug, test_case: v(test_case, :value))
      def reproduce(bug:, how:)       = dispatch("Bug.Reproduce", id: bug, demonstration: v(how))
      def investigate(bug:, site:, cause:) = dispatch("Bug.Investigate", id: bug, site: v(site), cause: v(cause))
      def fix(bug:, commit:)          = dispatch("Bug.Fix", id: bug, commit: v(commit))
      def verify(bug:)                = dispatch("Bug.Verify", id: bug)
      def pause_bug(bug:, reason:)    = dispatch("Bug.Pause", id: bug, reason: v(reason))
      def dismiss(bug:, reason:)      = dispatch("Bug.Dismiss", id: bug, reason: v(reason))
      def regress(bug:)               = dispatch("Bug.Regress", id: bug)
      def revisit(bug:)               = dispatch("Bug.Revisit", id: bug)
      def block(bug:, blocked_by:)    = dispatch("Bug.Block", id: bug, blocked_by: v(blocked_by))
      def unblock(bug:)               = dispatch("Bug.Unblock", id: bug, blocked_by: v("none"))

      # ── remedies ───────────────────────────────────────────────────────

      def attempt(bug:, engineer:, approach:)
        sequence  = next_sequence("Remedy")
        reference = "REM-#{sequence}"
        dispatch("Remedy.Attempt", bug_id: bug, reference: v(reference), sequence: v(sequence, :value),
                                   engineer: v(engineer), approach: v(approach))
        reference
      end

      def touch(remedy:, path:, note:) = dispatch("Remedy.Touch", id: remedy, path: v(path), note: v(note))
      def land(remedy:)                = dispatch("Remedy.Land", id: remedy)
      def abandon(remedy:, reason:)    = dispatch("Remedy.Abandon", id: remedy, reason: v(reason))
      def revert(remedy:, reason:)     = dispatch("Remedy.Revert", id: remedy, reason: v(reason))

      # ── tickets ────────────────────────────────────────────────────────

      # `body:` is optional and composed from the record when omitted — see
      # `#compose_body`. The point of holding a bug as data is that the
      # report it deserves is derivable; asking an agent to retype the
      # symptom into a ticket body is asking for the two to disagree.
      def draft_ticket(bug:, remedy:, repository:, title: nil, body: nil)
        record      = bug_record(bug)
        reference   = "TK-#{next_ticket_number}"
        title     ||= "#{bug}: #{field(record, :title)}"
        body      ||= compose_body(record, remedy)
        dispatch("Ticket.Draft", bug_id: bug, remedy_id: remedy,
                                 reference: v(reference), repository: v(repository),
                                 title: v(title), body: v(body))
        reference
      end

      def revise_ticket(ticket:, title:, body:) = dispatch("Ticket.Revise", id: ticket, title: v(title), body: v(body))
      def close_ticket(ticket:, resolution:)    = dispatch("Ticket.Close", id: ticket, resolution: v(resolution))
      def withdraw_ticket(ticket:)              = dispatch("Ticket.Withdraw", id: ticket)
      def retry_ticket(ticket:)                 = dispatch("Ticket.Retry", id: ticket)

      # THE ONE OPERATION THAT LEAVES THIS MACHINE.
      #
      # `Submit` first, so that a crash between the dispatch and the `gh`
      # call leaves a row in `Ticket.Submitting` — the state whose whole
      # purpose is to say "a call went out and nobody recorded the answer;
      # look at the tracker before retrying". Recording the submission
      # afterwards would lose exactly that case, which is the one worth
      # having.
      def file_ticket(ticket:)
        record = ticket_record(ticket)
        dispatch("Ticket.Submit", id: ticket)

        out, err, status = Open3.capture3(
          "gh", "issue", "create",
          "--repo",  field(record, :repository),
          "--title", field(record, :title),
          "--body",  field(record, :body),
          chdir: root
        )

        unless status.success?
          refusal = [err, out].map(&:to_s).reject(&:empty?).first || "gh exited #{status.exitstatus}"
          dispatch("Ticket.Failed", id: ticket, refusal: v(refusal.strip[0, 500]))
          return { filed: false, refusal: refusal.strip }
        end

        url    = out.to_s[%r{https?://\S+}] || ""
        number = url[%r{/(\d+)\s*\z}, 1].to_i
        dispatch("Ticket.Filed", id: ticket, number: v(number, :value), url: v(url))
        { filed: true, number: number, url: url }
      rescue Errno::ENOENT
        # `gh` is not installed. A refusal, recorded the same way any other
        # refusal from the tracker's side is — the ticket must not be left
        # sitting in `submitting` just because the failure was local.
        dispatch("Ticket.Failed", id: ticket, refusal: v("the gh CLI is not installed on this machine"))
        { filed: false, refusal: "the gh CLI is not installed on this machine" }
      end

      # ── reading ────────────────────────────────────────────────────────

      def query(name, **args) = materialize(@runtime.query("#{DOMAIN}::#{name}", **args))

      # THE DASHBOARD, AND EVERY LIST IN IT IS ONE THAT SHOULD BE EMPTY OR
      # SHORT. Ordered by how much a row costs: an unanswered filing may
      # already be a duplicate in a public tracker, an unreproduced bug
      # blocks its own workflow, an unresolved remedy is an unaccounted-for
      # working tree.
      def status
        {
          open_bugs:            query("Bug.Unfixed"),
          unreproduced:         query("Bug.Unreproduced"),
          blocked:              query("Bug.Blocked"),
          ready_to_verify:      query("Bug.ReadyToVerify"),
          paused:               query("Bug.Paused"),
          unresolved_remedies:  query("Remedy.Unresolved"),
          filings_unanswered:   query("Ticket.Submitting"),
          filings_failed:       query("Ticket.Failed"),
          resting_on_unreproduced: query("Ticket.RestingOnUnreproduced"),
          resting_on_live_remedy:  query("Ticket.RestingOnLiveRemedy"),
          resting_on_verified:     query("Ticket.RestingOnVerified"),
          failing_tests:        query("Session.TestCase.Failing"),
          unsettled_tests:      query("Session.TestCase.Unsettled"),
          ready_to_graduate:    query("Session.TestCase.ReadyToGraduate"),
          live_sessions:        query("Session.Testing")
        }
      end

      def bug_record(reference)
        query("Bug.All").find { |row| field(row, :reference) == reference } ||
          raise(Runtime::NotFound, "no bug in the ledger referenced #{reference.inspect}")
      end

      def ticket_record(reference)
        query("Ticket.All").find { |row| field(row, :reference) == reference } ||
          raise(Runtime::NotFound, "no ticket in the ledger referenced #{reference.inspect}")
      end

      # Everything known about one bug, gathered — the read an agent wants
      # before deciding what to do next, and the read a ticket is composed
      # from.
      def dossier(reference)
        record = bug_record(reference)
        {
          bug:      record,
          remedies: query("Remedy.ForBug", bug_id: v(reference)),
          tickets:  query("Ticket.ForBug", bug_id: v(reference))
        }
      end

      # COVERAGE, COUNTED. The chapter deliberately holds no `TestCoverage`
      # aggregate (see its header); this is that answer, assembled from rows
      # that cannot be stale because they are the rows themselves.
      def coverage(domain:)
        tests = query("Session.TestCase.ForDomain", domain: v(domain))
        bugs  = query("Bug.ForDomain", domain: v(domain))
        {
          domain:     domain,
          tests:      tests.length,
          categories: tests.map { |t| field(t, :category) }.uniq.sort,
          bugs:       bugs.length,
          open:       bugs.count { |b| %w[found reproduced investigating paused].include?(b[:status]) }
        }
      end

      # THE DAILY REPORT, RENDERED FROM THE LEDGER RATHER THAN TYPED.
      # `qa/reports/YYYY-MM-DD.md`'s own template, filled from records —
      # which is the difference between a report that describes the session
      # and one that was written during it and may not.
      def report(session:)
        bugs  = query("Bug.FoundIn", session_id: v(session))
        tests = query("Session.TestCase.Failing").select { |row| row[:session] == session }
        row   = query("Session.All").find { |s| field(s, :reference) == session }

        lines = ["# QA Report — #{session}", ""]
        lines << "**Engineer:** #{field(row, :engineer)}  "
        lines << "**Status:** #{row[:status]}  "
        lines << "**Tests written:** #{row.dig(:tested, :value)}"
        lines << ""
        lines << "## Bugs found (#{bugs.length})"
        lines << ""
        bugs.each do |bug|
          lines << "### #{field(bug, :reference)} — #{field(bug, :title)}"
          lines << ""
          lines << "- **Status:** #{bug[:status]}"
          lines << "- **Severity:** #{field(bug, :severity)}"
          lines << "- **Domain:** #{field(bug, :domain)}"
          lines << "- **Expected:** #{field(bug, :expectation)}"
          lines << "- **Actual:** #{field(bug, :symptom)}"
          lines << "- **Reproduction:** #{field(bug, :demonstration)}" if field(bug, :demonstration)
          lines << "- **Site:** #{field(bug, :site)}"               if field(bug, :site)
          lines << "- **Cause:** #{field(bug, :cause)}"             if field(bug, :cause)
          lines << "- **Commit:** #{field(bug, :commit)}"           if field(bug, :commit)
          lines << "- **Why stopped:** #{field(bug, :reason)}"      if field(bug, :reason)
          remedies = query("Remedy.ForBug", bug_id: v(field(bug, :reference)))
          remedies.each do |rem|
            lines << "- **Attempt #{field(rem, :reference)}** (#{rem[:status]}): #{field(rem, :approach)}"
          end
          lines << ""
        end
        lines << "## Failing tests still open (#{tests.length})"
        lines << ""
        tests.each { |t| lines << "- ##{t.dig(:sequence, :value)} #{field(t, :subject)} — #{field(t, :expectation)}" }
        lines << ""
        lines << "**Notes:** #{field(row, :notes)}" if field(row, :notes)
        lines.join("\n")
      end

      private

      def dispatch(verb, **args) = @runtime.dispatch("#{DOMAIN}::#{verb}", **args)

      # A single-field value object as the runtime wants it. Every value
      # object in this chapter has exactly one field, `value`, so this is
      # the whole of the argument shaping — the one thing a JSON caller
      # would otherwise have to know.
      def v(value, field = :value) = { field => value }

      def materialize(rows) = Facade::JsonDoor.materialize(rows)

      def field(row, name) = row.dig(name, :value)

      # SEQUENTIAL, WHICH IS WHY `All` EXISTS. Reading the maximum from a
      # filtered query would skip dismissed and verified records and reissue
      # a reference that is already in the ledger — the requirements' "BUG#1,
      # BUG#2, not BUG#999" read from the other end.
      def next_sequence(aggregate)
        query("#{aggregate}.All").map { |row| row.dig(:sequence, :value).to_i }.max.to_i + 1
      end

      def next_ticket_number = query("Ticket.All").length + 1

      def mint_session_reference
        today    = Time.now.strftime("%Y-%m-%d")
        existing = query("Session.All").map { |row| field(row, :reference) }
        candidate = "QA-#{today}"
        return candidate unless existing.include?(candidate)

        (2..).each do |n|
          nth = "#{candidate}-#{n}"
          return nth unless existing.include?(nth)
        end
      end

      # `qa/SOP.md` §6.1's issue template, filled from the record. The "Why
      # Not Fixed" section is the abandoned remedy's own reason, written on
      # the day the attempt ran out rather than recalled at filing time —
      # which is the entire reason `Remedy` is an aggregate.
      def compose_body(record, remedy_reference)
        remedy = query("Remedy.All").find { |r| field(r, :reference) == remedy_reference }
        changes = Array(remedy && remedy[:changes]).map { |c| "- `#{c[:path]}` — #{c[:note]}" }

        <<~MD
          ## Problem

          #{field(record, :title)}

          ## Expectation

          #{field(record, :expectation)}

          ## Actual behaviour

          #{field(record, :symptom)}

          ## Reproduction

          ```
          #{field(record, :demonstration) || 'not reproduced'}
          ```

          ## Root cause

          #{field(record, :cause) || 'not yet diagnosed'}

          Site: `#{field(record, :site) || 'unknown'}`

          ## Impact

          - Severity: #{field(record, :severity)}
          - Domain: #{field(record, :domain)}

          ## Why not fixed

          #{remedy ? field(remedy, :reason) : 'no attempt recorded'}

          Approach tried: #{remedy ? field(remedy, :approach) : '—'}
          #{changes.empty? ? '' : "\nFiles touched:\n#{changes.join("\n")}"}

          ---
          Raised from the QA ledger (`qa/bluebook/quality_control.bluebook`) as #{field(record, :reference)}.
        MD
      end
    end
  end
end
