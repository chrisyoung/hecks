# PRD 07 evaluation hook (docs/prds/07-ruby-mutation-testing.md) — NOT
# committed as a permanent part of the mutation-testing setup, kept here
# only for this evaluation run.
#
# mutant-rspec's default test selector (Mutant::Selector::Expression)
# correlates a subject to tests by parsing the first word of each
# example's full_description as a constant/method expression and matching
# it against the subject's own namespace. This codebase's specs are
# almost entirely prose-described (`RSpec.describe "the rules a command
# obeys"`), so that correlation finds ~0 tests for
# Hecksagain::Runtime::CommandInterpreter and its ArgumentGate/
# MutationApplier siblings — NOT because they're untested (a measured
# TracePoint coverage probe found 109 of ~150 top-level describe blocks
# genuinely execute code in these three files) but because mutant's
# naming heuristic can't see prose-described coverage at all.
#
# Given how broad that real coverage is (109/150 files — most of the
# suite), a targeted `mutant_expression` tagging fix would, in practice,
# select nearly the whole suite for nearly every subject anyway. So for
# this evaluation, skip the correlation entirely and always run every
# available test (the true suite, minus mutant's own default :fuzzing/
# :io exclusion) — the honest brute-force baseline the PRD's own "a
# mutation run is inherently O(mutants x suite runtime)" framing already
# expects, rather than a selection heuristic this codebase's spec style
# defeats.
# NOTE: uses `Mutant::Selector::Expression.class_eval do ... end`, NOT
# `module Mutant; class Selector; class Expression; ...; end; end; end`.
# Mutant's Hooks.load_pathname evals hook files inside a class-method
# binding (`def self.load_pathname` on Mutant::Hooks) — under a
# singleton-method binding, plain `module`/`class` reopening syntax
# resolves the constant against the wrong lexical scope and silently
# creates a disconnected shadow class instead of reopening the real one
# (confirmed with a minimal repro outside mutant entirely; this is a
# general Ruby `binding.eval` + singleton-method quirk, not mutant-
# specific). class_eval on the real constant sidesteps it.
Mutant::Selector::Expression.class_eval do
  def call(_subject)
    integration.available_tests
  end
end
