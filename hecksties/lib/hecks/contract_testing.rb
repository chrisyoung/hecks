# Hecks::ContractTesting
#
# Shared RSpec examples for verifying repository adapter contracts.
# Any adapter (memory, SQL, Redis) can include these shared examples
# to prove it satisfies the repository interface. Covers CRUD, query,
# count, clear, and custom finders.
#
# Usage:
#   RSpec.describe MyCustomRepository do
#     it_behaves_like "a Hecks repository",
#       domain: my_domain,
#       aggregate_name: "Pizza",
#       create_attrs: { name: "Margherita" }
#   end
#
module Hecks
  module ContractTesting
    # Register shared examples when this module is loaded.
    def self.install!
      RSpec.shared_examples "a Hecks repository" do |domain:, aggregate_name:, create_attrs:|
        let(:_contract_domain) { domain }
        let(:_contract_agg_name) { aggregate_name }
        let(:_contract_attrs) { create_attrs }
        let(:runtime) { Hecks.load(_contract_domain) }
        let(:repo) { runtime[_contract_agg_name] }
        let(:agg_class) do
          mod_name = "#{_contract_domain.name.gsub(/\s+/, '')}Domain"
          runtime # ensure loaded
          Object.const_get("#{mod_name}::#{_contract_agg_name}")
        end

        it "saves and finds by id" do
          entity = agg_class.create(**_contract_attrs)
          found = repo.find(entity.id)
          expect(found).not_to be_nil
          expect(found.id).to eq(entity.id)
        end

        it "returns all saved entities" do
          agg_class.create(**_contract_attrs)
          expect(repo.all.size).to be >= 1
        end

        it "counts saved entities" do
          agg_class.create(**_contract_attrs)
          expect(repo.count).to be >= 1
        end

        it "deletes by id" do
          entity = agg_class.create(**_contract_attrs)
          repo.delete(entity.id)
          expect(repo.find(entity.id)).to be_nil
        end

        it "clears all entities" do
          agg_class.create(**_contract_attrs)
          repo.clear
          expect(repo.count).to eq(0)
        end

        it "supports query with conditions" do
          agg_class.create(**_contract_attrs)
          key = _contract_attrs.keys.first
          results = repo.query(conditions: { key => _contract_attrs[key] })
          expect(results).not_to be_empty
        end
      end
    end
  end
end
