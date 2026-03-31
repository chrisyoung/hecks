require "spec_helper"
require "tempfile"

RSpec.describe Hecks::Import::SchemaParser do
  let(:schema_content) do
    <<~RUBY
      ActiveRecord::Schema.define(version: 2026_03_29_000000) do
        enable_extension "plpgsql"

        create_table "pizzas", force: :cascade do |t|
          t.string "name"
          t.text "description"
          t.integer "price"
          t.boolean "active"
          t.references "restaurant", foreign_key: true
          t.timestamps
        end

        create_table "toppings", force: :cascade do |t|
          t.string "name"
          t.integer "amount"
          t.references "pizza", foreign_key: true
          t.timestamps
        end

        create_table "schema_migrations", force: :cascade do |t|
          t.string "version"
        end

        create_table "ar_internal_metadata", force: :cascade do |t|
          t.string "key"
          t.string "value"
        end
      end
    RUBY
  end

  let(:schema_file) do
    f = Tempfile.new(["schema", ".rb"])
    f.write(schema_content)
    f.rewind
    f
  end

  after { schema_file.close! }

  subject(:tables) { described_class.new(schema_file.path).parse }

  it "extracts tables" do
    expect(tables.map { |t| t[:name] }).to contain_exactly("pizzas", "toppings")
  end

  it "skips Rails internal tables" do
    names = tables.map { |t| t[:name] }
    expect(names).not_to include("schema_migrations", "ar_internal_metadata")
  end

  it "extracts columns with types" do
    pizza = tables.find { |t| t[:name] == "pizzas" }
    names = pizza[:columns].map { |c| c[:name] }
    expect(names).to include("name", "description", "price", "active")
    expect(names).not_to include("id", "created_at", "updated_at")
  end

  it "extracts column types" do
    pizza = tables.find { |t| t[:name] == "pizzas" }
    name_col = pizza[:columns].find { |c| c[:name] == "name" }
    expect(name_col[:type]).to eq(:string)
    price_col = pizza[:columns].find { |c| c[:name] == "price" }
    expect(price_col[:type]).to eq(:integer)
  end

  it "extracts foreign keys from references" do
    pizza = tables.find { |t| t[:name] == "pizzas" }
    expect(pizza[:foreign_keys]).to include("restaurant_id")
    ref_col = pizza[:columns].find { |c| c[:name] == "restaurant_id" }
    expect(ref_col[:type]).to eq(:reference)
    expect(ref_col[:target]).to eq("restaurant")
  end
end
