# Hecksagon :searchable attribute tag spec
#
# Tests DSL parsing, fluent chaining, IR query, SQL index output, and
# generated search(term) method for the :searchable capability tag.
#
require "spec_helper"

RSpec.describe "Hecksagon :searchable attribute tag" do
  describe "DSL parsing" do
    it "stores :searchable tag via bare attribute (no capability. prefix)" do
      hex = Hecks.hecksagon do
        aggregate "Pizza" do
          capability.name.searchable
        end
      end

      tags = hex.aggregate_capabilities["Pizza"]
      expect(tags).to include({ attribute: "name", tag: :searchable })
    end

    it "supports multiple searchable fields on the same aggregate" do
      hex = Hecks.hecksagon do
        aggregate "Pizza" do
          capability.name.searchable
          capability.description.searchable
        end
      end

      tags = hex.aggregate_capabilities["Pizza"]
      expect(tags).to include({ attribute: "name", tag: :searchable })
      expect(tags).to include({ attribute: "description", tag: :searchable })
    end

    it "supports chained tags: notes.searchable.pii" do
      hex = Hecks.hecksagon do
        aggregate "Customer" do
          capability.notes.searchable.pii
        end
      end

      tags = hex.aggregate_capabilities["Customer"]
      expect(tags).to include({ attribute: "notes", tag: :searchable })
      expect(tags).to include({ attribute: "notes", tag: :pii })
    end
  end

  describe "IR query: searchable_fields" do
    let(:hex) do
      Hecks.hecksagon do
        aggregate "Pizza" do
          capability.name.searchable
          capability.description.searchable
        end
        aggregate "Customer" do
          capability.email.pii
        end
        aggregate "Product" do
          capability.sku.indexed
        end
      end
    end

    it "returns attribute names tagged :searchable for the aggregate" do
      expect(hex.searchable_fields("Pizza")).to eq(%w[name description])
    end

    it "returns empty array when no :searchable tags exist for aggregate" do
      expect(hex.searchable_fields("Customer")).to eq([])
    end

    it "returns empty array for unknown aggregate" do
      expect(hex.searchable_fields("Unknown")).to eq([])
    end

    it "does not include non-searchable tags in the result" do
      expect(hex.searchable_fields("Product")).to eq([])
    end
  end

  describe "SQL output from searchable_index_sql helper" do
    let(:helper) do
      Class.new { include Hecks::Migrations::Strategies::SqlHelpers }.new
    end

    it "emits a GIN tsvector index for Postgres with one field" do
      sql = helper.searchable_index_sql("pizzas", ["name"], adapter_type: :postgres)
      expect(sql).to include("CREATE INDEX idx_pizzas_fts ON pizzas")
      expect(sql).to include("USING gin")
      expect(sql).to include("to_tsvector")
      expect(sql).to include("coalesce(name::text, '')")
    end

    it "emits a GIN index covering multiple fields joined with ||" do
      sql = helper.searchable_index_sql("pizzas", %w[name description], adapter_type: :postgres)
      expect(sql).to include("coalesce(name::text, '')")
      expect(sql).to include("coalesce(description::text, '')")
    end

    it "returns nil for SQLite (LIKE fallback at query time)" do
      sql = helper.searchable_index_sql("pizzas", ["name"], adapter_type: :sqlite)
      expect(sql).to be_nil
    end

    it "returns nil when fields are empty" do
      sql = helper.searchable_index_sql("pizzas", [], adapter_type: :postgres)
      expect(sql).to be_nil
    end
  end

  describe "SqlMigrationGenerator with searchable fields" do
    let(:domain) do
      Hecks.domain "SearchSpec" do
        aggregate "Article" do
          attribute :title, String
          attribute :body, String
          command "CreateArticle" do
            attribute :title, String
          end
        end
      end
    end

    after { Object.send(:remove_const, :SearchSpecDomain) if defined?(SearchSpecDomain) }

    it "emits a GIN index when hecksagon has searchable fields (Postgres)" do
      hex = Hecks.hecksagon do
        aggregate "Article" do
          capability.title.searchable
          capability.body.searchable
        end
      end

      gen = Hecks::Generators::SQL::SqlMigrationGenerator.new(domain, hecksagon: hex)
      sql = gen.generate(adapter_type: :postgres)

      expect(sql).to include("CREATE INDEX idx_articles_fts ON articles")
      expect(sql).to include("USING gin")
    end

    it "omits the GIN index for SQLite (default adapter_type)" do
      hex = Hecks.hecksagon do
        aggregate "Article" do
          capability.title.searchable
        end
      end

      gen = Hecks::Generators::SQL::SqlMigrationGenerator.new(domain, hecksagon: hex)
      expect(gen.generate).not_to include("gin")
    end
  end

  describe "SqlAdapterGenerator generates search method" do
    let(:agg) do
      Hecks.domain("AdapterSearchSpec") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end.aggregates.first
    end

    after { Object.send(:remove_const, :AdapterSearchSpecDomain) if defined?(AdapterSearchSpecDomain) }

    it "includes search(term) when searchable_fields are given" do
      gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(
        agg, domain_module: "AdapterSearchSpecDomain", searchable_fields: ["name"]
      )
      code = gen.generate
      expect(code).to include("def search(term)")
      expect(code).to include("Sequel.ilike")
    end

    it "omits search method when no searchable_fields" do
      gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(
        agg, domain_module: "AdapterSearchSpecDomain"
      )
      expect(gen.generate).not_to include("def search(term)")
    end
  end
end
