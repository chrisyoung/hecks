# = Hecks::ContractTesting::RepositoryContract
#
# Shared RSpec examples that verify a repository adapter implements the
# full Hecks repository interface: find, save, delete, all, count,
# query, and clear. Any adapter that passes these examples is guaranteed
# to work with the Hecks runtime.
#
# == Usage
#
#   RSpec.describe MyAdapter do
#     include_examples "hecks repository contract",
#       adapter: -> { MyAdapter.new },
#       factory: -> { MyDomain::Pizza.new(name: "Margherita") }
#   end
#
module Hecks
  module ContractTesting
    module RepositoryContract
      def self.register!
        RSpec.shared_examples "hecks repository contract" do |adapter:, factory:|
          let(:repo) { adapter.call }
          let(:entity) { factory.call }

          after { repo.clear }

          describe "#save and #find" do
            it "persists and retrieves an entity by id" do
              repo.save(entity)
              found = repo.find(entity.id)
              expect(found).not_to be_nil
              expect(found.id).to eq(entity.id)
            end

            it "overwrites on duplicate save" do
              repo.save(entity)
              repo.save(entity)
              expect(repo.count).to eq(1)
            end
          end

          describe "#find" do
            it "returns nil for unknown id" do
              expect(repo.find("nonexistent-id")).to be_nil
            end
          end

          describe "#delete" do
            it "removes a persisted entity" do
              repo.save(entity)
              repo.delete(entity.id)
              expect(repo.find(entity.id)).to be_nil
            end

            it "is a no-op for unknown id" do
              expect { repo.delete("nonexistent-id") }.not_to raise_error
            end
          end

          describe "#all" do
            it "returns all persisted entities" do
              e1 = factory.call
              e2 = factory.call
              repo.save(e1)
              repo.save(e2)
              ids = repo.all.map(&:id)
              expect(ids).to contain_exactly(e1.id, e2.id)
            end

            it "returns empty array when empty" do
              expect(repo.all).to eq([])
            end
          end

          describe "#count" do
            it "returns the number of persisted entities" do
              repo.save(factory.call)
              repo.save(factory.call)
              expect(repo.count).to eq(2)
            end

            it "returns 0 when empty" do
              expect(repo.count).to eq(0)
            end
          end

          describe "#query" do
            it "filters by conditions" do
              e1 = factory.call
              e2 = factory.call
              repo.save(e1)
              repo.save(e2)
              results = repo.query(conditions: { id: e1.id })
              expect(results.size).to eq(1)
              expect(results.first.id).to eq(e1.id)
            end

            it "supports limit" do
              3.times { repo.save(factory.call) }
              results = repo.query(limit: 2)
              expect(results.size).to eq(2)
            end

            it "supports offset" do
              3.times { repo.save(factory.call) }
              all_results = repo.query
              offset_results = repo.query(offset: 1)
              expect(offset_results.size).to eq(2)
            end

            it "returns all when no filters given" do
              repo.save(factory.call)
              repo.save(factory.call)
              expect(repo.query.size).to eq(2)
            end
          end

          describe "#clear" do
            it "removes all entities" do
              repo.save(factory.call)
              repo.save(factory.call)
              repo.clear
              expect(repo.count).to eq(0)
            end
          end
        end
      end
    end
  end
end

# Auto-register when loaded under RSpec
Hecks::ContractTesting::RepositoryContract.register! if defined?(RSpec)
