# frozen_string_literal: true

require "open3"

module Hecksagain
  module Adapters
    # WHAT EVERY TOOL ADAPTER SHARES, AND NOTHING ELSE.
    #
    # `Rspec`, `Fuzzer` and `Toolchain` answer three different ports because
    # they are three different roles — you could swap the test runner without
    # touching the fuzzer, which is the whole reason a port is named after a
    # job rather than after a program. What they have in common is not a role
    # at all: how to run a subprocess, how to trim its output, and how to tell
    # "the tool ran" from "the tool could not run". That is mechanism, so it
    # lives in a module rather than in a base class nobody would be able to
    # name.
    #
    # `answers` IS "THE TOOL RAN", NOT "THE NEWS WAS GOOD".
    #
    # This is the distinction all three turn on, and it is easy to get
    # backwards. A fuzz run that finds a counterexample ANSWERED — the tool
    # worked, and the counterexample is the thing we wanted. A red spec run
    # ANSWERED. So `run` returns its output whatever the exit status, and only
    # raises when the tool could not run at all: no such script, no such
    # domain, a signal.
    #
    # Reading a red result as a refusal would be worse than merely wrong. It
    # would file every genuine finding into the same channel as a broken
    # toolchain, and the agent could no longer tell "the fuzzer found a bug"
    # from "the fuzzer is not installed" without reading prose.
    #
    # THE ONE PORT WHERE RED *IS* A REFUSAL IS `CI`, next door, and it is a
    # refusal there for a different question: not "what happens when you run
    # this" but "will you vouch for this commit".
    #
    # WHY THESE LIVE IN `qa/adapters/`. `Folder#load_library` globs
    # `lib/hecksagain/adapters/driven/` into EVERY registry any boot builds,
    # so an adapter there would answer its port for every consumer forever and
    # collide permanently with whatever a spec binds. `Folder#load_project`
    # globs this directory only when this domain boots.
    module Tooling
      # Big enough to hold a chapter's IR or a failing run's tail; small
      # enough that a durable ledger is not where transcripts go to live.
      LIMIT = 12_000

      def initialize(aggregate: nil, settings: {}, root: nil)
        @settings = settings
        @root     = root || checkout
      end

      private

      # THE CHECKOUT, FOUND RATHER THAN ASSUMED.
      #
      # This was `Dir.pwd`, which was true exactly as long as the only way in
      # was `bin/quality_control` typed at the repository root. The launcher
      # now lives beside its domain and boots `__dir__`, so it runs from
      # anywhere — and from anywhere, `bin/model_check` is not a file:
      #
      #   FuzzingRefused: cannot run bin/model_check: No such file or directory
      #
      # A refusal, correctly channelled, and completely misleading: the tool is
      # installed and working, the adapter was just looking in somebody's home
      # directory.
      #
      # WALKED UP TO, NOT COUNTED. `../..` from here would be right today and
      # wrong the moment this file moves — the same brittleness the launcher
      # just shed. Climbing until `lib/hecksagain` appears asks the question
      # directly, and `git rev-parse` was the alternative: a subprocess, and
      # nothing here needs the checkout to be a git one.
      def checkout
        @checkout ||= begin
          dir = __dir__
          dir = File.dirname(dir) while !File.directory?(File.join(dir, "lib", "hecksagain")) && File.dirname(dir) != dir
          File.directory?(File.join(dir, "lib", "hecksagain")) ? dir : Dir.pwd
        end
      end

      # THE ONE PLACE A TOOL IS ACTUALLY RUN, and the one place the
      # ran/succeeded distinction is made. `Open3` rather than backticks
      # because the exit status is part of the answer and stderr is most of
      # what a broken tool has to say.
      def run(*command, keep: :tail)
        out, err, status = Open3.capture3(*command, chdir: @root, unsetenv_others: false)
        answer([out, err].map(&:to_s).reject(&:empty?).join("\n"), status.exitstatus, keep: keep)
      rescue Errno::ENOENT => e
        # NOT A RESULT — the tool is not there. This is the case `refuses`
        # exists for, so it raises and `PortOperationInterpreter#ask` turns it
        # into the port's refusing event.
        raise "cannot run #{command.first}: #{e.message}"
      end

      # THE ANSWER'S KEYS ARE THE NEXT COMMAND'S ARGUMENTS — spread into the
      # answering event, not nested under one. Nothing reacts to these events
      # today; they are read. But the shape is the contract either way, and
      # `{ value: }` is what the runtime coerces.
      #
      # TRIMMED, because a full rspec run is megabytes and this goes into a
      # DURABLE ledger — a Postgres row that outlives the session.
      #
      # WHICH END TO KEEP IS NOT A DETAIL. A tool RUN puts its verdict at the
      # bottom — rspec's tally, the fuzzer's counterexample, git bisect's
      # verdict line — so the tail is the part worth having. A tool READ
      # (`bin/ir`, `bin/docs`) is a document, and its tail is the middle of a
      # sentence: truncating IR from the end hands back JSON that will not
      # parse, which is worse than useless to a caller with no shell to go and
      # look with.
      #
      # THE CUT SAYS SO, and says how much it dropped. A silent truncation is
      # how somebody concludes a chapter has no `Bug` aggregate.
      def answer(output, code, keep: :tail)
        text = output.to_s
        return { output: { value: text }, exit_status: { value: code.to_i } } if text.length <= LIMIT

        note = "[#{text.length - LIMIT} of #{text.length} characters dropped — narrow the scope to see it all]"
        kept = keep == :head ? "#{text[0, LIMIT]}\n#{note}" : "#{note}\n#{text[-LIMIT..]}"
        { output: { value: kept }, exit_status: { value: code.to_i } }
      end

      # A value object arrives as a Hash once `Value.materialize` has been
      # over it; a plain String is what a hand-written caller passes. Both are
      # legitimate and neither is worth making the caller think about.
      def text(field) = field.is_a?(Hash) ? field.values.first.to_s : field.to_s

      # A SCOPE MAY BE SEVERAL WORDS — `spec/a_spec.rb spec/b_spec.rb`, or a
      # domain and a flag. Split rather than shell-interpolated, so nothing
      # here is a place a quote character changes the command.
      def words(field) = text(field).split
    end
  end
end
