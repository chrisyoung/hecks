require "spec_helper"
require "tmpdir"
require "sqlite3"

RSpec.describe "SQL adapter integration" do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
          attribute :description, String
        end

        command "UpdatePizza" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :name, String
          attribute :description, String
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

  let(:tmpdir) { Dir.mktmpdir }
  let(:db) { SQLite3::Database.new(":memory:") }

  before do
    db.results_as_hash = true

    # Create tables
    db.execute <<~SQL
      CREATE TABLE pizzas (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255),
        description VARCHAR(255),
        created_at TEXT,
        updated_at TEXT
      )
    SQL

    db.execute <<~SQL
      CREATE TABLE pizzas_toppings (
        id VARCHAR(36) PRIMARY KEY,
        pizza_id VARCHAR(36) NOT NULL REFERENCES pizzas(id),
        name VARCHAR(255),
        amount INTEGER
      )
    SQL

    db.execute <<~SQL
      CREATE TABLE orders (
        id VARCHAR(36) PRIMARY KEY,
        pizza_id VARCHAR(36),
        quantity INTEGER,
        status VARCHAR(255),
        created_at TEXT,
        updated_at TEXT
      )
    SQL

    # Generate and load domain gem
    gen = Hecks::Generators::DomainGemGenerator.new(domain, version: "0.0.0", output_dir: tmpdir)
    gem_path = gen.generate
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "pizzas_domain.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }

    # Generate SQL adapters in memory
    domain.aggregates.each do |agg|
      gen = Hecks::Generators::SqlAdapterGenerator.new(agg, domain_module: "PizzasDomain")
      eval(gen.generate, TOPLEVEL_BINDING)
    end

    # Boot application with SQL adapters
    pizza_repo = PizzasDomain::Adapters::PizzaSqlRepository.new(db)
    order_repo = PizzasDomain::Adapters::OrderSqlRepository.new(db)
    @app = Hecks::Services::Application.new(domain) do
      adapter "Pizza", pizza_repo
      adapter "Order", order_repo
    end
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "Pizza.create" do
    it "persists to the database" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      expect(pizza.name).to eq("Margherita")
      expect(pizza.id).not_to be_nil

      row = db.execute("SELECT * FROM pizzas WHERE id = ?", [pizza.id]).first
      expect(row["name"]).to eq("Margherita")
    end

    it "sets timestamps" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      expect(pizza.created_at).to be_a(Time)
      expect(pizza.updated_at).to be_a(Time)
    end
  end

  describe "Pizza.find" do
    it "loads from the database with the correct ID" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      found = PizzasDomain::Pizza.find(pizza.id)
      expect(found.id).to eq(pizza.id)
      expect(found.name).to eq("Margherita")
    end

    it "returns nil for unknown ID" do
      expect(PizzasDomain::Pizza.find("nonexistent")).to be_nil
    end
  end

  describe "Pizza.all" do
    it "returns all pizzas" do
      PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      PizzasDomain::Pizza.create(name: "Pepperoni", description: "Spicy")
      expect(PizzasDomain::Pizza.all.size).to eq(2)
    end
  end

  describe "Pizza.count" do
    it "returns the count" do
      PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      expect(PizzasDomain::Pizza.count).to eq(1)
    end
  end

  describe "Pizza.where" do
    it "filters by attributes" do
      PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      PizzasDomain::Pizza.create(name: "Pepperoni", description: "Spicy")
      results = PizzasDomain::Pizza.where(name: "Pepperoni")
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Pepperoni")
    end

    it "chains where with order" do
      PizzasDomain::Pizza.create(name: "Pepperoni", description: "Classic")
      PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      PizzasDomain::Pizza.create(name: "Hawaiian", description: "Tropical")
      results = PizzasDomain::Pizza.where(description: "Classic").order(:name)
      expect(results.map(&:name)).to eq(["Margherita", "Pepperoni"])
    end

    it "chains where with order desc" do
      PizzasDomain::Pizza.create(name: "Pepperoni", description: "Classic")
      PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      results = PizzasDomain::Pizza.where(description: "Classic").order(name: :desc)
      expect(results.map(&:name)).to eq(["Pepperoni", "Margherita"])
    end

    it "chains where with limit and offset" do
      PizzasDomain::Pizza.create(name: "A", description: "Classic")
      PizzasDomain::Pizza.create(name: "B", description: "Classic")
      PizzasDomain::Pizza.create(name: "C", description: "Classic")
      results = PizzasDomain::Pizza.where(description: "Classic").order(:name).offset(1).limit(1)
      expect(results.map(&:name)).to eq(["B"])
    end
  end

  describe "Pizza.first / Pizza.last" do
    it "returns first and last" do
      PizzasDomain::Pizza.create(name: "First", description: "first")
      PizzasDomain::Pizza.create(name: "Last", description: "last")
      expect(PizzasDomain::Pizza.first.name).to eq("First")
      expect(PizzasDomain::Pizza.last.name).to eq("Last")
    end
  end

  describe "pizza.update" do
    it "preserves the ID" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      updated = pizza.update(name: "Margherita Deluxe")
      expect(updated.id).to eq(pizza.id)
      expect(updated.name).to eq("Margherita Deluxe")
    end

    it "persists the changes" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      pizza.update(name: "Margherita Deluxe")
      found = PizzasDomain::Pizza.find(pizza.id)
      expect(found.name).to eq("Margherita Deluxe")
    end

    it "preserves created_at" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      updated = pizza.update(name: "New")
      expect(updated.created_at.to_i).to eq(pizza.created_at.to_i)
    end
  end

  describe "pizza.destroy" do
    it "deletes from the database" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      pizza.destroy
      expect(PizzasDomain::Pizza.find(pizza.id)).to be_nil
      expect(PizzasDomain::Pizza.count).to eq(0)
    end

    it "deletes toppings too" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      pizza.toppings.create(name: "Cheese", amount: 2)
      pizza.destroy
      toppings = db.execute("SELECT COUNT(*) as c FROM pizzas_toppings").first["c"]
      expect(toppings).to eq(0)
    end
  end

  describe "pizza.save" do
    it "persists a manually constructed instance" do
      pizza = PizzasDomain::Pizza.new(name: "Custom", description: "Hand made")
      pizza.save
      found = PizzasDomain::Pizza.find(pizza.id)
      expect(found.name).to eq("Custom")
    end
  end

  describe "toppings collection proxy" do
    it "creates toppings" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      pizza.toppings.create(name: "Mozzarella", amount: 2)
      pizza.toppings.create(name: "Basil", amount: 1)

      found = PizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(2)
      expect(found.toppings.map(&:name)).to contain_exactly("Mozzarella", "Basil")
    end

    it "preserves pizza ID through topping creation" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      original_id = pizza.id
      pizza.toppings.create(name: "Cheese", amount: 1)
      expect(PizzasDomain::Pizza.find(original_id)).not_to be_nil
    end

    it "deletes toppings" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      pizza.toppings.create(name: "Mozzarella", amount: 2)
      pizza.toppings.create(name: "Basil", amount: 1)

      found = PizzasDomain::Pizza.find(pizza.id)
      basil = found.toppings.find { |t| t.name == "Basil" }
      found.toppings.delete(basil)

      reloaded = PizzasDomain::Pizza.find(pizza.id)
      expect(reloaded.toppings.count).to eq(1)
      expect(reloaded.toppings.first.name).to eq("Mozzarella")
    end
  end

  describe "reference resolution" do
    it "resolves order.pizza" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      order = PizzasDomain::Order.place(pizza_id: pizza.id, quantity: 3)
      expect(order.pizza.name).to eq("Margherita")
    end
  end

  describe "events" do
    it "fires events for commands" do
      PizzasDomain::Pizza.create(name: "Margherita", description: "Classic")
      expect(@app.events.size).to eq(1)
      expect(@app.events.first.class.name).to include("CreatedPizza")
    end
  end
end
