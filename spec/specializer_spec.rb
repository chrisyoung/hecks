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
  %w[Policy Bluebook].each do |category|
    it "derives #{category}'s fields exactly as hand-written" do
      derived = Hecksagain::Bluebook::Assembly::Specializer.fields_for(category)
      hand    = Hecksagain::Bluebook::Assembly.contract(category).fields

      expect(derived).to eq(hand)
    end
  end
end
