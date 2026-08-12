# frozen_string_literal: true

require "open3"

module Hecksagain
  module Adapters
    # CI, AND WHY A RED SUITE IS A REFUSAL HERE AND AN ANSWER NEXT DOOR.
    #
    # `Toolchain#run_specs` returns a red run as an ANSWER, because the sweep
    # asked "what happens when you run this" and a failure is the news it
    # wanted. This port asks a different question — "will you vouch for this
    # commit" — and to that question red is not news, it is NO. So the same
    # exit status means opposite things through the two ports, and that is not
    # an inconsistency: `answers`/`refuses` describes what the domain asked
    # for, and the two ports asked for different things.
    #
    # The chapter reads the same way. `Clearance.Failed` takes `refusal`
    # rather than `summary`, because the runtime names what comes back from a
    # refused ask `refusal`, and a policy hands its target the payload
    # verbatim.
    #
    # NOTHING IS DEPLOYED FROM HERE. This records that a suite ran against a
    # sha; `Clearance.For` answers whether that sha is safe to ship. Keeping
    # the record and the decision apart is what lets "nobody has run CI on
    # this at all" be a no for the right reason rather than a missing case.
    class Ci
      PATIENCE = 3_600

      def initialize(aggregate: nil, settings: {}, root: nil)
        @settings = settings
        @root     = root || Dir.pwd
      end

      # `commit` arrives from the record via `held_state` — the sha `Start`
      # put up. It is not re-passed as an argument, because then the run and
      # the record could disagree about which commit was tested, which is the
      # only fact this aggregate exists to hold.
      #
      # RANDOM ORDER, DELIBERATELY. A suite that only passes in file order is
      # a suite with order dependence in it, and this repository has five
      # examples of exactly that. Clearance is the gate that should see them.
      def run(commit: nil, **)
        out, err, status = Open3.capture3(
          "bundle", "exec", "rspec", "--order", "random",
          chdir: @root, unsetenv_others: false
        )
        said = summarise(out, err)

        raise "suite red against #{text(commit)}: #{said}" unless status.success?

        { summary: { value: "green: #{said}" } }
      end

      private

      # THE LINE THAT MATTERS. Rspec's last useful line is its tally
      # ("31 examples, 2 failures"); everything above it is backtrace, and a
      # `RunSummary` is read in a list of commits.
      def summarise(out, err)
        text = [out, err].map(&:to_s).join("\n")
        tally = text[/^\d+ examples?, \d+ failures?.*$/]
        (tally || text.lines.map(&:strip).reject(&:empty?).last || "no output")[0, 300]
      end

      def text(field) = field.is_a?(Hash) ? field.values.first.to_s : field.to_s
    end
  end
end
