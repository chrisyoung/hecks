# frozen_string_literal: true

require_relative "tooling"

module Hecksagain
  module Adapters
    # THE `Fuzzing` PORT — property-based search, kept apart from `Testing`
    # because it answers a different question and could be swapped
    # independently. A test run asks "does this case still work"; a fuzz run
    # asks "is there a case that does not", and a chapter that wanted a
    # different search strategy should be able to have one without the spec
    # runner noticing.
    #
    # A COUNTEREXAMPLE IS AN ANSWER, NOT A REFUSAL — see `Tooling`. This is
    # the operation where getting that backwards would hurt most: finding
    # something is the success case.
    class Fuzzer
      include Tooling

      def fuzz(scope:, **) = run("bin/fuzz", *words(scope))

      # THE OTHER SEARCH OVER THE SAME SPACE. `bin/model_check` looks for
      # unreachable states, dead transitions and policies wired to nothing —
      # findings a fuzzer reaches only by luck, because they are properties of
      # the model rather than of any run. Same port: both answer "is there
      # something wrong that nobody has written a test for yet".
      def model_check(scope:, **) = run("bin/model_check", *words(scope))
    end
  end
end
