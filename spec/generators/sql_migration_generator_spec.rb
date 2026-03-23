require "spec_helper"

RSpec.describe Hecks::Generators::SQL::SqlMigrationGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String
        attribute :price, Float
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
        end
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer
        attribute :status, String

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end
    end
  end

  subject(:generator) { described_class.new(domain) }

  describe "#generate" do
    let(:sql) { generator.generate }

    it "creates a table for each aggregate" do
      expect(sql).to include("CREATE TABLE pizzas")
      expect(sql).to include("CREATE TABLE orders")
    end

    it "includes id as primary key" do
      expect(sql).to include("id VARCHAR(36) PRIMARY KEY")
    end

    it "maps String to VARCHAR" do
      expect(sql).to include("name VARCHAR(255)")
    end

    it "maps Integer to INTEGER" do
      expect(sql).to include("quantity INTEGER")
    end

    it "maps Float to REAL" do
      expect(sql).to include("price REAL")
    end

    it "maps references to VARCHAR(36)" do
      expect(sql).to include("pizza_id VARCHAR(36)")
    end

    it "creates a join table for list value objects" do
      expect(sql).to include("CREATE TABLE pizzas_toppings")
      expect(sql).to include("pizza_id VARCHAR(36) NOT NULL REFERENCES pizzas(id)")
    end

    it "does not include list attributes as columns on the parent" do
      # toppings is a list, should not appear as a column on pizzas
      lines = sql.split("\n")
      pizzas_table = lines.take_while { |l| !l.include?(");") || l.include?("CREATE TABLE pizzas") }
      pizzas_section = sql.split("CREATE TABLE pizzas_toppings").first
      expect(pizzas_section).not_to include("toppings")
    end
  end
end
