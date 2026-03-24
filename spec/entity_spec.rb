require "spec_helper"

RSpec.describe "Sub-entities" do
  describe "IR: DomainModel::Structure::Entity" do
    it "stores name, attributes, and invariants" do
      entity = Hecks::DomainModel::Structure::Entity.new(
        name: "LedgerEntry",
        attributes: [
          Hecks::DomainModel::Structure::Attribute.new(name: :amount, type: Float),
          Hecks::DomainModel::Structure::Attribute.new(name: :description, type: String)
        ],
        invariants: []
      )
      expect(entity.name).to eq("LedgerEntry")
      expect(entity.attributes.size).to eq(2)
      expect(entity.attributes.first.name).to eq(:amount)
      expect(entity.invariants).to eq([])
    end

    it "defaults to empty attributes and invariants" do
      entity = Hecks::DomainModel::Structure::Entity.new(name: "Empty")
      expect(entity.attributes).to eq([])
      expect(entity.invariants).to eq([])
    end
  end

  describe "DSL: EntityBuilder" do
    it "builds an entity from DSL" do
      builder = Hecks::DSL::EntityBuilder.new("LedgerEntry")
      builder.attribute :amount, Float
      builder.attribute :description, String
      entity = builder.build

      expect(entity).to be_a(Hecks::DomainModel::Structure::Entity)
      expect(entity.name).to eq("LedgerEntry")
      expect(entity.attributes.map(&:name)).to eq([:amount, :description])
    end

    it "supports invariants" do
      builder = Hecks::DSL::EntityBuilder.new("LedgerEntry")
      builder.attribute :amount, Float
      builder.invariant("amount must be positive") { amount > 0 }
      entity = builder.build

      expect(entity.invariants.size).to eq(1)
      expect(entity.invariants.first.message).to eq("amount must be positive")
    end
  end

  describe "DSL: AggregateBuilder with entities" do
    it "stores entities on the aggregate" do
      domain = Hecks.domain("Banking") do
        aggregate "Account" do
          attribute :balance, Float

          entity "LedgerEntry" do
            attribute :amount, Float
            attribute :description, String
            attribute :entry_type, String
            attribute :posted_at, String
          end

          command "OpenAccount" do
            attribute :balance, Float
          end
        end
      end

      agg = domain.aggregates.first
      expect(agg.entities.size).to eq(1)
      expect(agg.entities.first.name).to eq("LedgerEntry")
      expect(agg.entities.first.attributes.map(&:name)).to eq([:amount, :description, :entry_type, :posted_at])
    end

    it "coexists with value objects" do
      domain = Hecks.domain("Test") do
        aggregate "Order" do
          attribute :total, Float

          value_object "Address" do
            attribute :street, String
          end

          entity "LineItem" do
            attribute :product, String
            attribute :quantity, Integer
          end

          command "CreateOrder" do
            attribute :total, Float
          end
        end
      end

      agg = domain.aggregates.first
      expect(agg.value_objects.size).to eq(1)
      expect(agg.entities.size).to eq(1)
      expect(agg.value_objects.first.name).to eq("Address")
      expect(agg.entities.first.name).to eq("LineItem")
    end
  end

  describe "Generator: EntityGenerator" do
    it "generates a class with Hecks::Model include" do
      entity = Hecks::DomainModel::Structure::Entity.new(
        name: "LedgerEntry",
        attributes: [
          Hecks::DomainModel::Structure::Attribute.new(name: :amount, type: Float),
          Hecks::DomainModel::Structure::Attribute.new(name: :description, type: String)
        ]
      )

      gen = Hecks::Generators::Domain::EntityGenerator.new(
        entity, domain_module: "BankingDomain", aggregate_name: "Account"
      )
      code = gen.generate

      expect(code).to include("class LedgerEntry")
      expect(code).to include("include Hecks::Model")
      expect(code).to include("attribute :amount")
      expect(code).to include("attribute :description")
      expect(code).not_to include("freeze")
    end
  end

  describe "Runtime: entities have identity and are mutable" do
    before(:all) do
      @domain = Hecks.domain("EntityTest") do
        aggregate "Account" do
          attribute :balance, Float

          entity "LedgerEntry" do
            attribute :amount, Float
            attribute :description, String
          end

          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      Hecks.build(@domain, version: "0.1.0", output_dir: "/tmp/entity_test")
      $LOAD_PATH.unshift("/tmp/entity_test/entity_test_domain/lib")
      require "entity_test_domain"
    end

    after(:all) do
      FileUtils.rm_rf("/tmp/entity_test")
      $LOAD_PATH.delete("/tmp/entity_test/entity_test_domain/lib")
    end

    it "has a UUID id" do
      entry = EntityTestDomain::Account::LedgerEntry.new(amount: 100.0, description: "test")
      expect(entry.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "is not frozen (mutable)" do
      entry = EntityTestDomain::Account::LedgerEntry.new(amount: 100.0, description: "test")
      expect(entry).not_to be_frozen
      entry.amount = 200.0
      expect(entry.amount).to eq(200.0)
    end

    it "uses identity-based equality" do
      id = SecureRandom.uuid
      a = EntityTestDomain::Account::LedgerEntry.new(amount: 100.0, description: "test", id: id)
      b = EntityTestDomain::Account::LedgerEntry.new(amount: 999.0, description: "other", id: id)
      expect(a).to eq(b)
    end

    it "is not equal when ids differ" do
      a = EntityTestDomain::Account::LedgerEntry.new(amount: 100.0, description: "test")
      b = EntityTestDomain::Account::LedgerEntry.new(amount: 100.0, description: "test")
      expect(a).not_to eq(b)
    end
  end

  describe "DslSerializer round-trip" do
    it "serializes entities using entity keyword" do
      domain = Hecks.domain("Test") do
        aggregate "Account" do
          attribute :balance, Float

          entity "LedgerEntry" do
            attribute :amount, Float
            attribute :description, String
          end

          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      dsl = Hecks::DslSerializer.new(domain).serialize
      expect(dsl).to include('entity "LedgerEntry"')
      expect(dsl).to include("attribute :amount, Float")
      expect(dsl).to include("attribute :description, String")
      expect(dsl).not_to include('value_object "LedgerEntry"')
    end
  end

  describe "AggregateRebuilder round-trip" do
    it "rebuilds entities from aggregate IR" do
      domain = Hecks.domain("Test") do
        aggregate "Account" do
          attribute :balance, Float

          entity "LedgerEntry" do
            attribute :amount, Float
          end

          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      agg = domain.aggregates.first
      builder = Hecks::DSL::AggregateRebuilder.from_aggregate(agg)
      rebuilt = builder.build

      expect(rebuilt.entities.size).to eq(1)
      expect(rebuilt.entities.first.name).to eq("LedgerEntry")
      expect(rebuilt.entities.first.attributes.first.name).to eq(:amount)
    end
  end

  describe "DomainDiff detects entity changes" do
    it "detects added entities" do
      old_domain = Hecks.domain("Test") do
        aggregate "Account" do
          attribute :balance, Float
          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      new_domain = Hecks.domain("Test") do
        aggregate "Account" do
          attribute :balance, Float

          entity "LedgerEntry" do
            attribute :amount, Float
          end

          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
      entity_changes = changes.select { |c| c.kind == :add_entity }
      expect(entity_changes.size).to eq(1)
      expect(entity_changes.first.details[:name]).to eq("LedgerEntry")
    end

    it "detects removed entities" do
      old_domain = Hecks.domain("Test") do
        aggregate "Account" do
          attribute :balance, Float
          entity "LedgerEntry" do
            attribute :amount, Float
          end
          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      new_domain = Hecks.domain("Test") do
        aggregate "Account" do
          attribute :balance, Float
          command "CreateAccount" do
            attribute :balance, Float
          end
        end
      end

      changes = Hecks::Migrations::DomainDiff.call(old_domain, new_domain)
      entity_changes = changes.select { |c| c.kind == :remove_entity }
      expect(entity_changes.size).to eq(1)
      expect(entity_changes.first.details[:name]).to eq("LedgerEntry")
    end
  end
end
