require "hecksagain"

RSpec.describe Hecksagain::Bluebook::DSL::QueryBuilder do
  describe "scope_to" do
    it "accepts any arguments and builds a query unaffected, a deliberate no-op" do
      query = described_class.build("Mine") do
        scope_to :player
      end

      expect(query).to be_a(Hecksagain::Bluebook::IR::Query)
      expect(query.name).to eq("Mine")
    end
  end
end
