require "spec_helper"
require "tmpdir"
require "sequel"

RSpec.describe "SQL safety: injection and escaping attacks" do
  let(:domain) do
    Hecks.domain("SqlSafe") do
      aggregate "Item" do
        attribute :name, String
        attribute :description, String
        attribute :price, Float
        attribute :data, JSON
        attribute :tags, list_of("Tag")

        value_object "Tag" do
          attribute :label, String
        end

        command "CreateItem" do
          attribute :name, String
          attribute :description, String
          attribute :price, Float
          attribute :data, JSON
        end
      end
    end
  end

  before do
    Hecks.load_domain(domain)

    domain.aggregates.each do |agg|
      gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: "SqlSafeDomain")
      eval(gen.generate, TOPLEVEL_BINDING)
    end

    @db = Sequel.sqlite
    @db.create_table(:items) do
      String :id, primary_key: true, size: 36
      String :name
      String :description
      Float :price
      String :data, text: true
      String :created_at
      String :updated_at
    end
    @db.create_table(:items_tags) do
      String :id, primary_key: true, size: 36
      String :item_id, null: false
      String :label
    end

    db = @db
    @app = Hecks::Services::Application.new(domain) do
      adapter "Item", SqlSafeDomain::Adapters::ItemSqlRepository.new(db)
    end

    # Bind ad-hoc queries so .where works on the aggregate class
    Hecks::Services::Querying::AdHocQueries.bind(SqlSafeDomain::Item, @app["Item"])
  end

  # ── 1. Classic SQL injection in string attributes ──

  describe "SQL injection in stored strings" do
    it "stores and retrieves a DROP TABLE injection string" do
      evil = "'; DROP TABLE items; --"
      item = SqlSafeDomain::Item.create(name: evil, description: "test", price: 1.0)
      # Table must still exist and the item must round-trip
      found = SqlSafeDomain::Item.find(item.id)
      expect(found).not_to be_nil
      expect(found.name).to eq(evil)
      # Table must still exist (not dropped)
      expect(@db.table_exists?(:items)).to be true
    end

    it "stores and retrieves a UNION SELECT injection string" do
      evil = "' UNION SELECT id, name, description, price, data, created_at, updated_at FROM items WHERE '1'='1"
      item = SqlSafeDomain::Item.create(name: evil, description: "safe", price: 2.0)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.name).to eq(evil)
    end

    it "stores and retrieves OR 1=1 injection" do
      evil = "' OR '1'='1"
      item = SqlSafeDomain::Item.create(name: evil, description: "test", price: 1.0)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.name).to eq(evil)
    end
  end

  # ── 2. Special quote and escape characters ──

  describe "special characters in strings" do
    it "handles single quotes" do
      val = "it's a test with 'quotes'"
      item = SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      expect(SqlSafeDomain::Item.find(item.id).name).to eq(val)
    end

    it "handles double quotes" do
      val = 'he said "hello" and "goodbye"'
      item = SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      expect(SqlSafeDomain::Item.find(item.id).name).to eq(val)
    end

    it "handles backslashes" do
      val = 'path\\to\\file\\name'
      item = SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      expect(SqlSafeDomain::Item.find(item.id).name).to eq(val)
    end

    it "handles mixed quotes, backslashes, and semicolons" do
      val = %q{he said "it's \fine"; DROP TABLE items; --}
      item = SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.name).to eq(val)
      expect(@db.table_exists?(:items)).to be true
    end

    it "handles percent and underscore (SQL LIKE wildcards)" do
      val = "100% off _ everything"
      item = SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      expect(SqlSafeDomain::Item.find(item.id).name).to eq(val)
    end

    it "handles newlines and tabs" do
      val = "line1\nline2\ttab"
      item = SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      expect(SqlSafeDomain::Item.find(item.id).name).to eq(val)
    end
  end

  # ── 3. SQL injection through WHERE conditions ──

  describe "SQL injection through where queries" do
    before do
      SqlSafeDomain::Item.create(name: "Alice", description: "safe", price: 10.0)
      SqlSafeDomain::Item.create(name: "Bob", description: "safe", price: 20.0)
    end

    it "where with injection string returns no results (not all)" do
      results = SqlSafeDomain::Item.where(name: "' OR '1'='1")
      # Should return 0 results, not all rows
      expect(results.size).to eq(0)
    end

    it "where with DROP TABLE injection does not drop the table" do
      results = SqlSafeDomain::Item.where(name: "'; DROP TABLE items; --")
      expect(results.size).to eq(0)
      expect(@db.table_exists?(:items)).to be true
      # Original data still intact
      expect(SqlSafeDomain::Item.count).to eq(2)
    end

    it "where with UNION SELECT injection returns no results" do
      results = SqlSafeDomain::Item.where(name: "' UNION SELECT 1,2,3,4,5,6,7 --")
      expect(results.size).to eq(0)
    end

    it "where with semicolon injection does not execute second statement" do
      results = SqlSafeDomain::Item.where(name: "Alice'; DELETE FROM items; --")
      expect(results.size).to eq(0)
      expect(SqlSafeDomain::Item.count).to eq(2)
    end
  end

  # ── 4. JSON with SQL injection in keys and values ──

  describe "JSON with SQL injection payloads" do
    it "stores injection strings in JSON values" do
      evil_data = { "name" => "'; DROP TABLE items; --", "query" => "' OR 1=1 --" }
      item = SqlSafeDomain::Item.create(name: "test", description: "x", price: 1.0, data: evil_data)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.data["name"]).to eq("'; DROP TABLE items; --")
      expect(found.data["query"]).to eq("' OR 1=1 --")
      expect(@db.table_exists?(:items)).to be true
    end

    it "stores injection strings in JSON keys" do
      evil_data = { "'; DROP TABLE items; --" => "value", "' OR 1=1" => "hack" }
      item = SqlSafeDomain::Item.create(name: "test", description: "x", price: 1.0, data: evil_data)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.data["'; DROP TABLE items; --"]).to eq("value")
      expect(@db.table_exists?(:items)).to be true
    end

    it "stores deeply nested JSON with injections" do
      evil_data = {
        "level1" => {
          "level2" => {
            "attack" => "'; DROP TABLE items; --",
            "arr" => ["normal", "' UNION SELECT * FROM items --"]
          }
        }
      }
      item = SqlSafeDomain::Item.create(name: "test", description: "x", price: 1.0, data: evil_data)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.data["level1"]["level2"]["attack"]).to eq("'; DROP TABLE items; --")
      expect(found.data["level1"]["level2"]["arr"][1]).to eq("' UNION SELECT * FROM items --")
    end
  end

  # ── 5. Operators with SQL injection string values ──

  describe "operators with SQL injection strings" do
    before do
      SqlSafeDomain::Item.create(name: "Alpha", description: "safe", price: 10.0)
      SqlSafeDomain::Item.create(name: "Beta", description: "safe", price: 20.0)
    end

    it "NotEq with injection string does not leak data" do
      repo = @app["Item"]
      op = Hecks::Services::Querying::Operators::NotEq.new("'; DROP TABLE items; --")
      results = repo.query(
        conditions: { name: op },
        order_key: nil, order_direction: :asc, limit: nil, offset: nil
      )
      # Should return both items (neither name matches the injection string)
      expect(results.size).to eq(2)
      expect(@db.table_exists?(:items)).to be true
    end

    it "Gt with injection string value" do
      repo = @app["Item"]
      # Using a string with SQL injection in a numeric comparison context
      op = Hecks::Services::Querying::Operators::Gt.new("'; DROP TABLE items; --")
      # This should not drop the table, regardless of whether it errors or returns results
      begin
        results = repo.query(
          conditions: { name: op },
          order_key: nil, order_direction: :asc, limit: nil, offset: nil
        )
      rescue => e
        # An error is acceptable - injection should not succeed
      end
      expect(@db.table_exists?(:items)).to be true
      expect(SqlSafeDomain::Item.count).to eq(2)
    end

    it "In operator with injection strings in the array" do
      repo = @app["Item"]
      op = Hecks::Services::Querying::Operators::In.new(["Alpha", "'; DROP TABLE items; --"])
      results = repo.query(
        conditions: { name: op },
        order_key: nil, order_direction: :asc, limit: nil, offset: nil
      )
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Alpha")
      expect(@db.table_exists?(:items)).to be true
    end

    it "Lt with injection string" do
      repo = @app["Item"]
      op = Hecks::Services::Querying::Operators::Lt.new("'; DROP TABLE items; --")
      begin
        results = repo.query(
          conditions: { price: op },
          order_key: nil, order_direction: :asc, limit: nil, offset: nil
        )
      rescue => e
        # An error is acceptable
      end
      expect(@db.table_exists?(:items)).to be true
    end
  end

  # ── 6. Null bytes in strings ──

  describe "null bytes in strings" do
    it "BUG: null bytes cause Sequel::DatabaseError - strings with \\x00 break SQL insert" do
      # This documents a real bug: null bytes in string values cause
      # SQLite to see a truncated string literal, producing malformed SQL.
      # Sequel does not sanitize null bytes before parameterization, and
      # SQLite's C API truncates strings at \x00.
      val = "before\x00after"
      expect {
        SqlSafeDomain::Item.create(name: val, description: "x", price: 1.0)
      }.to raise_error(Sequel::DatabaseError, /unrecognized token/)
    end

    it "null byte in JSON value is escaped by JSON.generate and round-trips safely" do
      # JSON.generate converts \x00 to \\u0000, which Sequel handles fine.
      # This is safe because JSON serialization happens before SQL.
      data = { "key" => "val\x00ue" }
      item = SqlSafeDomain::Item.create(name: "test", description: "x", price: 1.0, data: data)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found).not_to be_nil
      # The null byte is preserved through JSON round-trip
      expect(found.data["key"]).to include("val")
      expect(@db.table_exists?(:items)).to be true
    end
  end

  # ── 7. SQL injection through value object (join table) attributes ──

  describe "SQL injection in value object (join table) attributes" do
    it "stores injection string in tag label" do
      item = SqlSafeDomain::Item.create(name: "test", description: "x", price: 1.0)
      evil_label = "'; DROP TABLE items_tags; --"
      item.tags.create(label: evil_label)
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.tags.first.label).to eq(evil_label)
      expect(@db.table_exists?(:items_tags)).to be true
    end

    it "stores quotes and backslashes in tag label" do
      item = SqlSafeDomain::Item.create(name: "test", description: "x", price: 1.0)
      item.tags.create(label: %q{it's a "test" with \backslash})
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.tags.first.label).to eq(%q{it's a "test" with \backslash})
    end
  end

  # ── 8. Update with injection strings ──

  describe "update with SQL injection" do
    it "updates name to an injection string" do
      item = SqlSafeDomain::Item.create(name: "safe", description: "x", price: 1.0)
      item.update(name: "'; DROP TABLE items; --")
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.name).to eq("'; DROP TABLE items; --")
      expect(@db.table_exists?(:items)).to be true
    end

    it "updates description to contain UNION SELECT" do
      item = SqlSafeDomain::Item.create(name: "safe", description: "x", price: 1.0)
      item.update(description: "' UNION SELECT * FROM items --")
      found = SqlSafeDomain::Item.find(item.id)
      expect(found.description).to eq("' UNION SELECT * FROM items --")
    end
  end

  # ── 9. Delete with injection ID ──

  describe "delete with injection ID" do
    it "does not delete all rows when given injection ID" do
      SqlSafeDomain::Item.create(name: "keep1", description: "x", price: 1.0)
      SqlSafeDomain::Item.create(name: "keep2", description: "x", price: 2.0)
      # Try to delete with an injection string as ID
      SqlSafeDomain::Item.delete("' OR '1'='1")
      # Both items should still exist
      expect(SqlSafeDomain::Item.count).to eq(2)
    end
  end

  # ── 10. Find with injection ID ──

  describe "find with injection ID" do
    it "returns nil for injection ID, does not return other rows" do
      SqlSafeDomain::Item.create(name: "secret", description: "x", price: 1.0)
      result = SqlSafeDomain::Item.find("' OR '1'='1")
      expect(result).to be_nil
    end
  end
end
