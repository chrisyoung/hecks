require "spec_helper"

RSpec.describe "the first specializer" do
  # Handler swapped for Bluebook this session (migration plan task 4):
  # Handler grew a real `list_of` field (`remembers`, the saga-memory
  # open map — see reaction.bluebook's own comment), which the
  # specializer deliberately never claims ("ONE CASE, PROVEN, NOT THE
  # WHOLE TABLE" — Specializer#fields_for's own header). Handler's
  # hand-written contract and the specializer's derived one can no
  # longer agree field-for-field, which is not a regression — it is
  # exactly what "not the whole table" always meant, now actually
  # exercised. Bluebook is the next category whose own `fields:` table
  # is ALL plain scalars (no lists, no references), so it takes
  # Handler's place as the second independently-checked category.
  #
  # Policy dropped from the list this session (migration plan task 8),
  # the same way and for the same reason Handler was: `wheres`/
  # `with_literals`/`for_each_where` are real `list_of` fields now (see
  # reaction.bluebook's own comment), so the specializer skips them —
  # `wheres`/`with_literals`/`for_each` in the hand-written contract, and
  # the specializer's own OPPOSITE miss, `for_each_from` (a genuine plain
  # scalar the specializer claims but the hand-written table intentionally
  # keeps out of `fields:` — `derived: [:computed, :for_each_from]`
  # instead, since `IR::Policy#for_each` is what the constructor actually
  # takes, not the two halves the language keeps it split into). No
  # replacement left this covers: every remaining category the language
  # declares carries at least one list or reference field (see
  # `Assembly::CONTRACTS`), so Bluebook alone stays the proof.
  %w[Bluebook].each do |category|
    it "derives #{category}'s fields exactly as hand-written" do
      derived = Hecksagain::Bluebook::Assembly::Specializer.fields_for(category)
      hand    = Hecksagain::Bluebook::Assembly.contract(category).fields

      expect(derived).to eq(hand)
    end
  end
end
