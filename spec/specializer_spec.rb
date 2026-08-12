require "spec_helper"

RSpec.describe "the first specializer" do
  # Handler swapped for Bluebook (item 36), Policy WITHDRAWN with no
  # replacement (this item, 94fdc44/46b): Policy grew three real
  # `list_of`/compound fields (`wheres`/`with_literals`/`for_each` -- see
  # reaction.bluebook's own comment), which the specializer deliberately
  # never claims ("ONE CASE, PROVEN, NOT THE WHOLE TABLE" -- Specializer#
  # fields_for's own header). Policy's hand-written contract and the
  # specializer's derived one can no longer agree field-for-field, which
  # is not a regression -- it is exactly what "not the whole table"
  # always meant, now actually exercised a second time.
  #
  # Checked every one of the twelve contract-backed categories directly
  # (a real, one-time audit, not a guess): Bluebook is the ONLY one left
  # with a `fields:` table this migration's own growth hasn't touched.
  # `Member`'s own `fields: {}` looked like a second candidate but is not
  # a genuine match -- its own `shape` attribute is real on the language
  # side yet marked `derived: { shape: :parent }` (not a stored field) on
  # the hand-written contract, a PRE-EXISTING mismatch unrelated to this
  # migration, not something to paper over by picking it anyway. Rather
  # than fake a second category, this drops to the one real, honestly
  # checkable claim left.
  %w[Bluebook].each do |category|
    it "derives #{category}'s fields exactly as hand-written" do
      derived = Hecksagain::Bluebook::Assembly::Specializer.fields_for(category)
      hand    = Hecksagain::Bluebook::Assembly.contract(category).fields

      expect(derived).to eq(hand)
    end
  end
end
