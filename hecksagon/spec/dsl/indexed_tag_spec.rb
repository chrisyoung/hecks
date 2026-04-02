# Hecksagon DSL indexed tag spec
#
# Tests the :indexed attribute tag: DSL parsing, chaining, IR query,
# and SQL output from SqlMigrationGenerator and SqlStrategy.
#
require "spec_helper"

RSpec.describe "Hecksagon :indexed attribute tag" do
  describe "DSL parsing" do
    it "stores :indexed tag via capability. prefix" do
      hex = Hecks.hecksagon do
        aggregate "Customer" do
          capability.created_at.indexed
        end
      end

      tags = hex.aggregate_capabilities["Customer"]
      expect(tags).to include({ attribute: "created_at", tag: :indexed })
    end

    it "stores :indexed tag via bare attribute (no capability. prefix)" do
      hex = Hecks.hecksagon do
        aggregate "Customer" do
          created_at.indexed
        end
      end

      tags = hex.aggregate_capabilities["Customer"]
      expect(tags).to include({ attribute: "created_at", tag: :indexed })
    end

    it "supports chained tags: ssn.privacy.indexed" do
      hex = Hecks.hecksagon do
        aggregate "Customer" do
          ssn.privacy.indexed
        end
      end

      tags = hex.aggregate_capabilities["Customer"]
      expect(tags).to include({ attribute: "ssn", tag: :privacy })
      expect(tags).to include({ attribute: "ssn", tag: :indexed })
    end
  end

  describe "IR query: indexed_attributes_for" do
    it "returns attribute names tagged :indexed for the aggregate" do
      hex = Hecks.hecksagon do
        aggregate "Order" do
          capability.created_at.indexed
          capability.status.indexed
          capability.total.audit
        end
      end

      indexed = hex.indexed_attributes_for("Order")
      expect(indexed).to eq(["created_at", "status"])
    end

    it "returns empty array when no :indexed tags" do
      hex = Hecks.hecksagon do
        aggregate "Order" do
          capability.total.audit
        end
      end

      expect(hex.indexed_attributes_for("Order")).to eq([])
    end

    it "returns empty array for unknown aggregate" do
      hex = Hecks.hecksagon {}
      expect(hex.indexed_attributes_for("Unknown")).to eq([])
    end
  end

  describe "SQL output from SqlMigrationGenerator" do
    let(:domain) do
      Hecks.domain "Shop" do
        aggregate "Product" do
          attribute :sku, String
          attribute :created_at, String
          command "CreateProduct" do
            attribute :sku, String
          end
        end
      end
    end

    it "emits no CREATE INDEX when no hecksagon given" do
      gen = Hecks::Generators::SQL::SqlMigrationGenerator.new(domain)
      sql = gen.generate
      expect(sql).not_to include("CREATE INDEX")
    end

    it "emits CREATE INDEX for :indexed attributes when hecksagon given" do
      hex = Hecks.hecksagon do
        aggregate "Product" do
          capability.created_at.indexed
        end
      end

      gen = Hecks::Generators::SQL::SqlMigrationGenerator.new(domain, hecksagon: hex)
      sql = gen.generate
      expect(sql).to include("CREATE INDEX idx_products_created_at ON products(created_at);")
    ensure
      Object.send(:remove_const, :ShopDomain) if defined?(ShopDomain)
    end
  end
end
