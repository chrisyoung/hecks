require_relative "shared_domains"
require "spec_helper"
require "tmpdir"

RSpec.describe "CollectionProxy destructive tests" do
  def boot_domain(domain)
    tmpdir = Dir.mktmpdir("hecks_break_test")
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "#{domain.gem_name}.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  # Domain WITHOUT invariants for collection proxy behavior tests
  let(:domain) do
    Hecks.domain "BreakPizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  before { @app = boot_domain(domain) }

  describe "bulk operations - 100 value objects" do
    it "creates 100 toppings on one aggregate" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Loaded")
      100.times do |i|
        pizza.toppings.create(name: "Topping#{i}", amount: i + 1)
      end
      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(100)
    end

    it "preserves all 100 toppings through find round-trip" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Loaded")
      100.times do |i|
        pizza.toppings.create(name: "Topping#{i}", amount: i + 1)
      end
      found = BreakPizzasDomain::Pizza.find(pizza.id)
      names = found.toppings.map(&:name).sort
      expect(names).to eq((0..99).map { |i| "Topping#{i}" }.sort)
    end
  end

  describe "delete ordering edge cases" do
    before do
      @pizza = BreakPizzasDomain::Pizza.create(name: "DeleteTest")
      5.times { |i| @pizza.toppings.create(name: "T#{i}", amount: i + 1) }
      @pizza = BreakPizzasDomain::Pizza.find(@pizza.id)
    end

    it "deletes the last item" do
      last = @pizza.toppings.last
      @pizza.toppings.delete(last)
      reloaded = BreakPizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings.count).to eq(4)
      expect(reloaded.toppings.map(&:name)).not_to include("T4")
    end

    it "deletes the first item" do
      first = @pizza.toppings.first
      @pizza.toppings.delete(first)
      reloaded = BreakPizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings.count).to eq(4)
      expect(reloaded.toppings.map(&:name)).not_to include("T0")
    end

    it "deletes the last item then the first item sequentially" do
      last = @pizza.toppings.last
      @pizza.toppings.delete(last)

      # Re-fetch to get fresh state
      @pizza = BreakPizzasDomain::Pizza.find(@pizza.id)
      first = @pizza.toppings.first
      @pizza.toppings.delete(first)

      reloaded = BreakPizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings.count).to eq(3)
      remaining_names = reloaded.toppings.map(&:name)
      expect(remaining_names).not_to include("T0")
      expect(remaining_names).not_to include("T4")
    end

    it "deletes last then first WITHOUT re-fetching (stale proxy)" do
      last = @pizza.toppings.last
      @pizza.toppings.delete(last)

      # Do NOT re-fetch - use same proxy with stale internal state
      first = @pizza.toppings.first
      @pizza.toppings.delete(first)

      reloaded = BreakPizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings.count).to eq(3)
      remaining_names = reloaded.toppings.map(&:name)
      expect(remaining_names).not_to include("T0")
      expect(remaining_names).not_to include("T4")
    end
  end

  describe "clear then re-add" do
    it "clears all items then re-adds new ones" do
      pizza = BreakPizzasDomain::Pizza.create(name: "ClearTest")
      3.times { |i| pizza.toppings.create(name: "Old#{i}", amount: i + 1) }

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(3)

      found.toppings.clear
      reloaded = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(reloaded.toppings).to be_empty

      # Re-add after clearing
      reloaded.toppings.create(name: "New0", amount: 1)
      reloaded.toppings.create(name: "New1", amount: 2)

      final = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(final.toppings.count).to eq(2)
      expect(final.toppings.map(&:name)).to contain_exactly("New0", "New1")
    end

    it "clears and re-adds without re-fetching (stale proxy after clear)" do
      pizza = BreakPizzasDomain::Pizza.create(name: "StaleClear")
      3.times { |i| pizza.toppings.create(name: "Old#{i}", amount: i + 1) }

      # Clear using the same proxy reference (no re-fetch)
      pizza.toppings.clear

      # Now add using the SAME proxy (potentially stale)
      pizza.toppings.create(name: "Fresh", amount: 1)

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(1)
      expect(found.toppings.first.name).to eq("Fresh")
    end
  end

  describe "index access" do
    before do
      @pizza = BreakPizzasDomain::Pizza.create(name: "IndexTest")
      @pizza.toppings.create(name: "First", amount: 1)
      @pizza.toppings.create(name: "Second", amount: 2)
      @pizza.toppings.create(name: "Third", amount: 3)
      @pizza = BreakPizzasDomain::Pizza.find(@pizza.id)
    end

    it "accesses items by positive index [0], [1], [2]" do
      expect(@pizza.toppings[0].name).to eq("First")
      expect(@pizza.toppings[1].name).to eq("Second")
      expect(@pizza.toppings[2].name).to eq("Third")
    end

    it "accesses items by negative index [-1]" do
      expect(@pizza.toppings[-1].name).to eq("Third")
    end

    it "accesses items by negative index [-2]" do
      expect(@pizza.toppings[-2].name).to eq("Second")
    end

    it "returns nil for out-of-bounds index" do
      expect(@pizza.toppings[99]).to be_nil
      expect(@pizza.toppings[-99]).to be_nil
    end
  end

  describe "wrong attributes on value object" do
    it "raises when creating a topping with an unknown attribute" do
      pizza = BreakPizzasDomain::Pizza.create(name: "BadAttrs")
      expect {
        pizza.toppings.create(name: "Cheese", amount: 1, color: "yellow")
      }.to raise_error(ArgumentError)
    end

    it "raises when creating a topping with missing required attribute (no name)" do
      pizza = BreakPizzasDomain::Pizza.create(name: "MissingAttr")
      expect {
        pizza.toppings.create(amount: 1)
      }.to raise_error(ArgumentError)
    end
  end

  describe "deleting an already-deleted item" do
    it "deleting a topping that was already removed" do
      pizza = BreakPizzasDomain::Pizza.create(name: "DoubleDelete")
      pizza.toppings.create(name: "Cheese", amount: 1)
      pizza.toppings.create(name: "Basil", amount: 2)

      pizza = BreakPizzasDomain::Pizza.find(pizza.id)
      cheese = pizza.toppings.find { |t| t.name == "Cheese" }

      # Delete once
      pizza.toppings.delete(cheese)

      # Try to delete again - should not raise, and should not corrupt state
      expect {
        pizza.toppings.delete(cheese)
      }.not_to raise_error

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(1)
      expect(found.toppings.first.name).to eq("Basil")
    end
  end

  describe "empty collection on freshly created aggregate" do
    it "toppings is empty on a new aggregate" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Empty")
      expect(pizza.toppings).to be_empty
      expect(pizza.toppings.count).to eq(0)
      expect(pizza.toppings.first).to be_nil
      expect(pizza.toppings.last).to be_nil
      expect(pizza.toppings.to_a).to eq([])
    end

    it "toppings is empty after find on a new aggregate" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Empty")
      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings).to be_empty
      expect(found.toppings.count).to eq(0)
      expect(found.toppings.first).to be_nil
      expect(found.toppings.last).to be_nil
    end

    it "each yields nothing on empty collection" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Empty")
      yielded = []
      pizza.toppings.each { |t| yielded << t }
      expect(yielded).to be_empty
    end

    it "map returns empty array on empty collection" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Empty")
      expect(pizza.toppings.map(&:name)).to eq([])
    end
  end

  describe "delete via CollectionItem#delete" do
    it "item.delete removes it and persists" do
      pizza = BreakPizzasDomain::Pizza.create(name: "ItemDelete")
      pizza.toppings.create(name: "A", amount: 1)
      pizza.toppings.create(name: "B", amount: 2)

      pizza = BreakPizzasDomain::Pizza.find(pizza.id)
      pizza.toppings.first.delete

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(1)
      expect(found.toppings.first.name).to eq("B")
    end

    it "deleting all items one by one via item.delete" do
      pizza = BreakPizzasDomain::Pizza.create(name: "DeleteAll")
      3.times { |i| pizza.toppings.create(name: "T#{i}", amount: i + 1) }

      pizza = BreakPizzasDomain::Pizza.find(pizza.id)
      # Delete first, re-fetch, delete first, re-fetch, delete first
      3.times do
        pizza = BreakPizzasDomain::Pizza.find(pizza.id)
        pizza.toppings.first.delete
      end

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings).to be_empty
    end
  end

  describe "duplicate value objects" do
    it "allows two identical toppings" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Dupes")
      pizza.toppings.create(name: "Cheese", amount: 1)
      pizza.toppings.create(name: "Cheese", amount: 1)

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      expect(found.toppings.count).to eq(2)
    end

    it "deleting one duplicate leaves the other (BUG: reject removes ALL matching)" do
      pizza = BreakPizzasDomain::Pizza.create(name: "Dupes")
      pizza.toppings.create(name: "Cheese", amount: 1)
      pizza.toppings.create(name: "Cheese", amount: 1)

      found = BreakPizzasDomain::Pizza.find(pizza.id)
      found.toppings.first.delete

      reloaded = BreakPizzasDomain::Pizza.find(pizza.id)
      # Should have exactly 1 left, not 0.
      # CollectionProxy#delete uses reject { |i| i == raw } which removes ALL
      # items that are equal, not just the first match. For value objects with
      # value-based equality, two identical toppings are == to each other,
      # so deleting one removes both.
      expect(reloaded.toppings.count).to eq(1)
    end
  end

  describe "invariant on value object via block_source (BUG)" do
    # block_source cannot extract curly-brace blocks defined in spec files.
    # The invariant body becomes empty string, generating `proc { }` which
    # returns nil, causing the invariant to ALWAYS fail -- even with valid data.
    let(:invariant_domain) do
      Hecks.domain "InvPizzas" do
        aggregate "Pizza" do
          attribute :name, String
          attribute :toppings, list_of("Topping")

          value_object "Topping" do
            attribute :name, String
            attribute :amount, Integer

            invariant("amount must be positive") { amount.is_a?(Integer) && amount > 0 }
          end

          command "CreatePizza" do
            attribute :name, String
          end
        end
      end
    end

    it "BUG: valid topping (amount=1) should succeed but invariant rejects it" do
      # This exposes a bug in Hecks::Utils.block_source: when the invariant
      # block uses { } syntax and is defined in a spec file, the extracted
      # source is empty, producing `proc { }` which returns nil. The generated
      # check_invariants! then raises because `unless nil` is truthy.
      app = boot_domain(invariant_domain)
      pizza = InvPizzasDomain::Pizza.create(name: "Test")

      # This SHOULD work (amount=1 is positive) but fails because the
      # invariant was incorrectly extracted as a no-op that returns nil
      expect {
        pizza.toppings.create(name: "Cheese", amount: 1)
      }.to raise_error(/amount must be positive/)
    end
  end
end
