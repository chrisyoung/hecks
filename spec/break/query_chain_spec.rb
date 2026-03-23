require_relative "shared_domains"
require "spec_helper"
require "tmpdir"

RSpec.describe "QueryBuilder destructive tests" do
  def boot_domain(domain)
    tmpdir = Dir.mktmpdir("hecks_break_test")
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "#{domain.gem_name}.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  let(:domain) do
    Hecks.domain "Breaker" do
      aggregate "Item" do
        attribute :name, String
        attribute :category, String
        attribute :color, String
        attribute :size, String
        attribute :weight, Integer

        command "CreateItem" do
          attribute :name, String
          attribute :category, String
          attribute :color, String
          attribute :size, String
          attribute :weight, Integer
        end
      end
    end
  end

  before do
    @app = boot_domain(domain)
    repo = @app["Item"]
    Hecks::Services::Querying::AdHocQueries.bind(BreakerDomain::Item, repo)

    BreakerDomain::Item.create(name: "Alpha",   category: "A", color: "red",   size: "S", weight: 1)
    BreakerDomain::Item.create(name: "Bravo",   category: "A", color: "blue",  size: "M", weight: 2)
    BreakerDomain::Item.create(name: "Charlie", category: "B", color: "red",   size: "L", weight: 3)
    BreakerDomain::Item.create(name: "Delta",   category: "B", color: "green", size: "S", weight: 4)
    BreakerDomain::Item.create(name: "Echo",    category: "C", color: "blue",  size: "M", weight: 5)
  end

  describe "where with empty hash" do
    it "returns all items when given an empty hash" do
      results = BreakerDomain::Item.where(**{})
      expect(results.to_a.size).to eq(5)
    end
  end

  describe "order by nonexistent attribute" do
    it "does not raise when ordering by an attribute that doesn't exist" do
      expect {
        BreakerDomain::Item.order(:nonexistent_field).to_a
      }.not_to raise_error
    end

    it "still returns all items" do
      results = BreakerDomain::Item.order(:nonexistent_field).to_a
      expect(results.size).to eq(5)
    end
  end

  describe "limit(0)" do
    it "returns an empty array" do
      results = BreakerDomain::Item.limit(0).to_a
      expect(results).to eq([])
    end

    it "count is 0" do
      expect(BreakerDomain::Item.limit(0).count).to eq(0)
    end
  end

  describe "limit(-1)" do
    it "does not raise an error" do
      # Array#take(-1) raises ArgumentError: negative array size
      # This is a bug if QueryBuilder doesn't guard against it
      expect {
        BreakerDomain::Item.limit(-1).to_a
      }.not_to raise_error
    end

    it "returns an empty array for negative limit" do
      results = BreakerDomain::Item.limit(-1).to_a
      expect(results).to eq([])
    end
  end

  describe "offset larger than total count" do
    it "returns empty when offset exceeds item count" do
      results = BreakerDomain::Item.offset(100).to_a
      expect(results).to eq([])
    end

    it "count is 0 when offset exceeds item count" do
      expect(BreakerDomain::Item.offset(100).count).to eq(0)
    end
  end

  describe "offset(-1)" do
    it "does not raise an error" do
      # Array#drop(-1) raises ArgumentError: attempt to drop negative size
      # This is a bug if QueryBuilder doesn't guard against it
      expect {
        BreakerDomain::Item.offset(-1).to_a
      }.not_to raise_error
    end

    it "returns all items for negative offset (treated as 0)" do
      results = BreakerDomain::Item.offset(-1).to_a
      expect(results.size).to eq(5)
    end
  end

  describe "deeply chained where clauses" do
    it "chains 5 where calls on different fields and returns correct results" do
      results = BreakerDomain::Item
        .where(category: "A")
        .where(color: "red")
        .where(size: "S")
        .where(weight: 1)
        .where(name: "Alpha")
      expect(results.to_a.size).to eq(1)
      expect(results.first.name).to eq("Alpha")
    end

    it "chains 5 where calls that match nothing" do
      results = BreakerDomain::Item
        .where(category: "A")
        .where(color: "red")
        .where(size: "L")
        .where(weight: 1)
        .where(name: "Alpha")
      expect(results.to_a).to be_empty
    end
  end

  describe "find_by with multiple conditions" do
    it "finds with two conditions" do
      result = BreakerDomain::Item.find_by(category: "B", color: "green")
      expect(result).not_to be_nil
      expect(result.name).to eq("Delta")
    end

    it "returns nil when one condition doesn't match" do
      result = BreakerDomain::Item.find_by(category: "A", color: "green")
      expect(result).to be_nil
    end
  end

  describe "to_a idempotency" do
    it "calling to_a twice returns the same results" do
      query = BreakerDomain::Item.where(category: "A").order(:name)
      first_call = query.to_a
      second_call = query.to_a
      expect(first_call.map(&:name)).to eq(second_call.map(&:name))
    end

    it "to_a does not mutate the query object" do
      query = BreakerDomain::Item.where(category: "A")
      query.to_a
      expect(query.count).to eq(2)
    end
  end

  describe "count after limit" do
    it "count respects the limit (returns limited count, not total)" do
      # This tests whether count returns the number of items AFTER limit
      # is applied, or the total matching count. QueryBuilder#count calls
      # execute.size, which applies limit, so count should equal the
      # limited result size.
      total = BreakerDomain::Item.where(category: "A").count
      limited = BreakerDomain::Item.where(category: "A").limit(1).count
      expect(total).to eq(2)
      expect(limited).to eq(1)
    end
  end

  describe "limit(nil) and offset(nil)" do
    it "limit(nil) returns all items (no limit applied)" do
      results = BreakerDomain::Item.limit(nil).to_a
      expect(results.size).to eq(5)
    end

    it "offset(nil) returns all items (no offset applied)" do
      results = BreakerDomain::Item.offset(nil).to_a
      expect(results.size).to eq(5)
    end
  end
end
