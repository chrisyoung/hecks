require "spec_helper"

RSpec.describe Hecks::DomainModel::Structure::PersistenceMetadata do
  describe "defaults" do
    subject(:meta) { described_class.new }

    it "has empty indexes" do
      expect(meta.indexes).to eq([])
    end

    it "has nil identity_fields" do
      expect(meta.identity_fields).to be_nil
    end
  end

  describe "with values" do
    subject(:meta) do
      described_class.new(
        indexes: [{ fields: [:email], unique: true }],
        identity_fields: [:team, :start_date]
      )
    end

    it "stores indexes" do
      expect(meta.indexes).to eq([{ fields: [:email], unique: true }])
    end

    it "stores identity_fields" do
      expect(meta.identity_fields).to eq([:team, :start_date])
    end
  end

  describe "Aggregate integration" do
    it "delegates indexes to persistence_metadata" do
      meta = described_class.new(indexes: [{ fields: [:name], unique: false }])
      agg = Hecks::DomainModel::Structure::Aggregate.new(
        name: "Pizza", persistence_metadata: meta
      )

      expect(agg.indexes).to eq([{ fields: [:name], unique: false }])
      expect(agg.persistence_metadata).to equal(meta)
    end

    it "delegates identity_fields to persistence_metadata" do
      meta = described_class.new(identity_fields: [:slug])
      agg = Hecks::DomainModel::Structure::Aggregate.new(
        name: "Pizza", persistence_metadata: meta
      )

      expect(agg.identity_fields).to eq([:slug])
    end

    it "builds persistence_metadata from legacy kwargs" do
      agg = Hecks::DomainModel::Structure::Aggregate.new(
        name: "Pizza",
        indexes: [{ fields: [:name], unique: false }],
        identity_fields: [:name]
      )

      expect(agg.persistence_metadata).to be_a(described_class)
      expect(agg.indexes).to eq([{ fields: [:name], unique: false }])
      expect(agg.identity_fields).to eq([:name])
    end
  end

  describe "DSL integration" do
    it "populates persistence_metadata from DSL index declarations" do
      domain = Hecks.domain "PMetaTest" do
        aggregate "User" do
          attribute :email, String
          index :email, unique: true
          identity :email
          command "CreateUser" do
            attribute :email, String
          end
        end
      end

      user = domain.aggregates.first
      expect(user.persistence_metadata).to be_a(described_class)
      expect(user.indexes).to eq([{ fields: [:email], unique: true }])
      expect(user.identity_fields).to eq([:email])
    end
  end
end
