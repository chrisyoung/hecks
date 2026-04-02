require "spec_helper"

# Mock Redis client -- hash-based, no gem required.
# Implements get/set/del/mget/scan to exercise RedisRepository.
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

  def del(*keys)
    keys.flatten.each { |k| @store.delete(k) }
  end

  def mget(*keys)
    keys.flatten.map { |k| @store[k] }
  end

  def scan(cursor, match:, count: 100)
    pattern = Regexp.new("\\A" + Regexp.escape(match).gsub("\\*", ".*") + "\\z")
    matching = @store.keys.select { |k| k.match?(pattern) }
    ["0", matching]
  end
end

require "hecks/extensions/redis_store"

RSpec.describe Hecks::RedisRepository do
  before(:all) do
    domain = Hecks.domain "RedisTest" do
      aggregate "Widget" do
        attribute :name, String
        attribute :weight, Integer

        command "CreateWidget" do
          attribute :name, String
          attribute :weight, Integer
        end
      end
    end
    @app = Hecks.load(domain)
  end

  let(:mock_redis) { MockRedis.new }

  let(:repo) do
    Hecks::RedisRepository.new(
      "Widget",
      RedisTestDomain::Widget,
      redis: mock_redis,
      namespace: "hecks:redistest:widget"
    )
  end

  def build_widget(name:, weight:)
    cmd = RedisTestDomain::Widget.create(name: name, weight: weight)
    cmd.aggregate
  end

  describe "#save and #find" do
    it "round-trips an aggregate" do
      widget = build_widget(name: "Sprocket", weight: 42)
      repo.save(widget)

      found = repo.find(widget.id)
      expect(found).not_to be_nil
      expect(found.id).to eq(widget.id)
      expect(found.name).to eq("Sprocket")
      expect(found.weight).to eq(42)
    end

    it "returns nil for missing id" do
      expect(repo.find("nonexistent")).to be_nil
    end
  end

  describe "#delete" do
    it "removes an aggregate" do
      widget = build_widget(name: "Gone", weight: 1)
      repo.save(widget)
      repo.delete(widget.id)

      expect(repo.find(widget.id)).to be_nil
    end
  end

  describe "#all" do
    it "returns all saved aggregates" do
      w1 = build_widget(name: "A", weight: 1)
      w2 = build_widget(name: "B", weight: 2)
      repo.save(w1)
      repo.save(w2)

      expect(repo.all.map(&:name).sort).to eq(["A", "B"])
    end

    it "returns empty array when nothing saved" do
      expect(repo.all).to eq([])
    end
  end

  describe "#count" do
    it "returns the number of stored aggregates" do
      expect(repo.count).to eq(0)

      w1 = build_widget(name: "X", weight: 1)
      repo.save(w1)
      expect(repo.count).to eq(1)
    end
  end

  describe "#query" do
    before do
      [
        { name: "Alpha", weight: 30 },
        { name: "Beta",  weight: 10 },
        { name: "Gamma", weight: 20 }
      ].each do |attrs|
        w = build_widget(**attrs)
        repo.save(w)
      end
    end

    it "filters by conditions" do
      results = repo.query(conditions: { name: "Beta" })
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Beta")
    end

    it "sorts by order_key ascending" do
      results = repo.query(order_key: :weight)
      expect(results.map(&:weight)).to eq([10, 20, 30])
    end

    it "sorts descending" do
      results = repo.query(order_key: :weight, order_direction: :desc)
      expect(results.map(&:weight)).to eq([30, 20, 10])
    end

    it "applies limit and offset" do
      results = repo.query(order_key: :weight, limit: 1, offset: 1)
      expect(results.size).to eq(1)
      expect(results.first.weight).to eq(20)
    end
  end

  describe "#clear" do
    it "removes all stored aggregates" do
      w = build_widget(name: "Temp", weight: 0)
      repo.save(w)
      expect(repo.count).to eq(1)

      repo.clear
      expect(repo.count).to eq(0)
    end
  end

  describe "key namespace" do
    it "stores under hecks:domain:aggregate:id" do
      widget = build_widget(name: "Keyed", weight: 5)
      repo.save(widget)

      raw = mock_redis.get("hecks:redistest:widget:#{widget.id}")
      expect(raw).not_to be_nil
      parsed = JSON.parse(raw)
      expect(parsed["name"]).to eq("Keyed")
    end
  end

  describe "extension registration" do
    it "registers :redis_store in the extension registry" do
      expect(Hecks.extension_registry[:redis_store]).not_to be_nil
    end

    it "aliases :redis to :redis_store" do
      expect(Hecks.extension_registry[:redis]).to eq(Hecks.extension_registry[:redis_store])
    end
  end
end
