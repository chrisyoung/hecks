require "spec_helper"
require "hecks/extensions/redis_store"

# Mock Redis client for testing
class MockRedis
  def initialize
    @store = {}
  end

  def get(key)
    @store[key]
  end

  def set(key, value)
    @store[key] = value
  end

  def del(key)
    @store.delete(key)
  end

  def scan(cursor, match:, count: 100)
    pattern = Regexp.new("\\A" + Regexp.escape(match).gsub("\\*", ".*") + "\\z")
    keys = @store.keys.select { |k| k.match?(pattern) }
    ["0", keys]
  end
end

RSpec.describe Hecks::RedisRepository do
  let(:client) { MockRedis.new }
  let(:repo) { described_class.new(client: client, prefix: "test:pizza") }

  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  it "saves and finds an aggregate by id" do
    app = Hecks.load(domain)
    pizza = PizzasDomain::Pizza.create(name: "Margherita")

    repo.save(pizza)
    found = repo.find(pizza.id)

    expect(found).to be_a(Hash)
    expect(found["name"]).to eq("Margherita")
    expect(found["id"]).to eq(pizza.id)
  end

  it "returns nil for missing id" do
    expect(repo.find("missing")).to be_nil
  end

  it "deletes by id" do
    app = Hecks.load(domain)
    pizza = PizzasDomain::Pizza.create(name: "Test")
    repo.save(pizza)
    repo.delete(pizza.id)
    expect(repo.find(pizza.id)).to be_nil
  end

  it "counts and clears" do
    app = Hecks.load(domain)
    p1 = PizzasDomain::Pizza.create(name: "A")
    p2 = PizzasDomain::Pizza.create(name: "B")
    repo.save(p1)
    repo.save(p2)

    expect(repo.count).to eq(2)
    expect(repo.all.size).to eq(2)

    repo.clear
    expect(repo.count).to eq(0)
  end

  it "wires via extend" do
    app = Hecks.load(domain)
    app.extend(:redis_store, client: client)
    # After extending, the adapter is a RedisRepository
    expect(app["Pizza"]).to be_a(Hecks::RedisRepository)
  end
end
