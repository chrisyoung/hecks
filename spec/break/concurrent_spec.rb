require "spec_helper"
require "tmpdir"

RSpec.describe "Destructive testing: concurrency, ordering, and state corruption" do
  def boot(domain)
    tmpdir = Dir.mktmpdir("hecks_break_test")
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "#{domain.gem_name}.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  # --- Test 1: Two aggregates with the same name in the same domain ---
  describe "duplicate aggregate names in one domain" do
    it "second aggregate definition overwrites the first silently" do
      # Defining two aggregates named "Widget" in the same domain.
      # This should either raise an error or cleanly merge -- not corrupt state.
      domain = Hecks.domain("DupAgg") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end

        aggregate "Widget" do
          attribute :label, String
          command "CreateWidget" do
            attribute :label, String
          end
        end
      end

      # If we get here, the domain accepted duplicates. Check which one "won".
      widget_aggs = domain.aggregates.select { |a| a.name == "Widget" }

      # BUG if both exist -- duplicate aggregates in the same context
      if widget_aggs.size > 1
        # Document the bug: domain has two aggregates with the same name.
        # This will cause ambiguous wiring and the second will shadow the first.
        fail "BUG: Domain accepted two aggregates named 'Widget' without error. " \
             "Count: #{widget_aggs.size}. This causes ambiguous wiring."
      else
        # Only one survived -- check which attributes it has
        attrs = widget_aggs.first.attributes.map(&:name)
        expect(attrs).to include(:label).or include(:name)
      end
    end
  end

  # --- Test 2: Update an aggregate while iterating over all ---
  describe "mutate during iteration" do
    it "updating an aggregate while iterating over .all" do
      domain = Hecks.domain("IterMut") do
        aggregate "Item" do
          attribute :name, String
          command "CreateItem" do
            attribute :name, String
          end
        end
      end
      app = boot(domain)

      mod = Object.const_get("IterMutDomain")
      klass = mod::Item

      klass.create(name: "alpha")
      klass.create(name: "beta")
      klass.create(name: "gamma")

      # Iterate over all items and update each one mid-iteration.
      # In a hash-backed store, modifying during iteration can raise
      # RuntimeError or produce inconsistent results.
      expect {
        klass.all.each do |item|
          item.update(name: item.name.upcase)
        end
      }.not_to raise_error

      # Verify all items were updated
      names = klass.all.map(&:name)
      expect(names).to contain_exactly("ALPHA", "BETA", "GAMMA")
    end
  end

  # --- Test 3: Delete an aggregate then try to update it ---
  describe "update after delete" do
    it "updating a destroyed aggregate re-inserts it into the store" do
      domain = Hecks.domain("DelUp") do
        aggregate "Thing" do
          attribute :title, String
          command "CreateThing" do
            attribute :title, String
          end
        end
      end
      app = boot(domain)

      klass = DelUpDomain::Thing
      thing = klass.create(title: "Original")
      original_id = thing.id

      # Destroy it
      thing.destroy
      expect(klass.find(original_id)).to be_nil
      expect(klass.count).to eq(0)

      # Now update the stale reference -- this calls repo.save with the old ID
      # BUG: The destroyed object is silently re-inserted into the store
      updated = thing.update(title: "Zombie")

      zombie_count = klass.count
      if zombie_count > 0
        # Document: destroyed aggregates can be resurrected via .update
        fail "BUG: Calling .update on a destroyed aggregate re-inserted it. " \
             "Count is now #{zombie_count}. The aggregate is a zombie: " \
             "find(#{original_id}) => #{klass.find(original_id)&.title.inspect}"
      else
        expect(klass.find(original_id)).to be_nil
      end
    end
  end

  # --- Test 4: Save on a destroyed aggregate ---
  describe "save after destroy" do
    it "calling .save on a destroyed aggregate re-inserts it" do
      domain = Hecks.domain("SaveDead") do
        aggregate "Record" do
          attribute :data, String
          command "CreateRecord" do
            attribute :data, String
          end
        end
      end
      app = boot(domain)

      klass = SaveDeadDomain::Record
      record = klass.create(data: "alive")
      record_id = record.id

      record.destroy
      expect(klass.find(record_id)).to be_nil

      # Now call save on the destroyed object
      record.save

      if klass.find(record_id)
        fail "BUG: Calling .save on a destroyed aggregate resurrected it. " \
             "find(#{record_id}) => #{klass.find(record_id).data.inspect}. " \
             "Destroyed aggregates should refuse to save."
      else
        expect(klass.count).to eq(0)
      end
    end
  end

  # --- Test 5: Query referencing a nonexistent attribute ---
  describe "query on nonexistent attribute" do
    it "where clause on a nonexistent attribute returns empty (no error)" do
      domain = Hecks.domain("BadQ") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
      app = boot(domain)

      klass = BadQDomain::Widget
      Hecks::Services::Querying::AdHocQueries.bind(klass, app["Widget"])
      klass.create(name: "test")
      klass.create(name: "test2")

      # Query for an attribute that does not exist on Widget
      # Should this raise? Or silently return empty?
      results = klass.where(nonexistent_field: "anything")

      # Document behavior: querying a nonexistent attribute silently returns
      # empty rather than warning or raising.
      expect(results.to_a).to be_empty
    end

    it "ordering by a nonexistent attribute does not raise" do
      domain = Hecks.domain("BadOrder") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
      app = boot(domain)

      klass = BadOrderDomain::Widget
      Hecks::Services::Querying::AdHocQueries.bind(klass, app["Widget"])
      klass.create(name: "alpha")
      klass.create(name: "beta")

      # Order by a field that doesn't exist
      expect {
        results = klass.order(:totally_fake_field).to_a
        # All items should still be returned, just not meaningfully sorted
        expect(results.size).to eq(2)
      }.not_to raise_error
    end
  end

  # --- Test 6: Chain 10+ where/order/limit calls ---
  describe "deeply chained query operations" do
    it "chains 10+ where/order/limit/offset calls" do
      domain = Hecks.domain("DeepChain") do
        aggregate "Product" do
          attribute :name, String
          attribute :price, Float
          attribute :category, String
          command "CreateProduct" do
            attribute :name, String
            attribute :price, Float
            attribute :category, String
          end
        end
      end
      app = boot(domain)

      klass = DeepChainDomain::Product
      Hecks::Services::Querying::AdHocQueries.bind(klass, app["Product"])

      # Create a bunch of products
      20.times do |i|
        klass.create(name: "Product_#{i}", price: i * 1.5, category: i.even? ? "even" : "odd")
      end

      # Chain 12 operations
      result = klass
        .where(category: "even")        # 1
        .where(category: "even")         # 2 (redundant, should not break)
        .order(:price)                   # 3
        .order(price: :desc)             # 4 (override previous order)
        .limit(15)                       # 5
        .limit(10)                       # 6 (override previous limit)
        .offset(0)                       # 7
        .offset(1)                       # 8 (override previous offset)
        .where(category: "even")         # 9 (redundant again)
        .order(:name)                    # 10 (override order again)
        .limit(5)                        # 11
        .offset(0)                       # 12

      expect { result.to_a }.not_to raise_error
      items = result.to_a
      expect(items.size).to be <= 5
      # All returned items should be in "even" category
      items.each { |item| expect(item.category).to eq("even") }
    end

    it "chaining where accumulates conditions" do
      domain = Hecks.domain("AccumWhere") do
        aggregate "Item" do
          attribute :color, String
          attribute :size, String
          command "CreateItem" do
            attribute :color, String
            attribute :size, String
          end
        end
      end
      app = boot(domain)

      klass = AccumWhereDomain::Item
      Hecks::Services::Querying::AdHocQueries.bind(klass, app["Item"])
      klass.create(color: "red", size: "large")
      klass.create(color: "red", size: "small")
      klass.create(color: "blue", size: "large")

      # Chain two where calls with different keys -- should AND them
      results = klass.where(color: "red").where(size: "large").to_a
      expect(results.size).to eq(1)
      expect(results.first.color).to eq("red")
      expect(results.first.size).to eq("large")
    end
  end

  # --- Test 7: Concurrent thread access to the same repo ---
  describe "thread safety" do
    it "concurrent creates do not lose data" do
      domain = Hecks.domain("ThreadSafe") do
        aggregate "Counter" do
          attribute :value, Integer
          command "CreateCounter" do
            attribute :value, Integer
          end
        end
      end
      app = boot(domain)

      klass = ThreadSafeDomain::Counter

      threads = 10.times.map do |i|
        Thread.new do
          10.times do |j|
            klass.create(value: i * 10 + j)
          end
        end
      end

      threads.each(&:join)

      count = klass.count
      if count != 100
        fail "BUG: Thread-unsafe repository. Expected 100 items, got #{count}. " \
             "Concurrent creates lost #{100 - count} items."
      end
    end
  end

  # --- Test 8: Delete while iterating ---
  describe "delete during iteration" do
    it "deleting items while iterating over .all" do
      domain = Hecks.domain("DelIter") do
        aggregate "Entry" do
          attribute :label, String
          command "CreateEntry" do
            attribute :label, String
          end
        end
      end
      app = boot(domain)

      klass = DelIterDomain::Entry
      5.times { |i| klass.create(label: "entry_#{i}") }

      # Try to delete each item while iterating
      # This modifies the underlying hash during iteration
      expect {
        klass.all.each do |entry|
          entry.destroy
        end
      }.not_to raise_error

      expect(klass.count).to eq(0)
    end
  end

  # --- Test 9: Double destroy ---
  describe "double destroy" do
    it "destroying the same aggregate twice does not raise" do
      domain = Hecks.domain("DoubleDel") do
        aggregate "Item" do
          attribute :name, String
          command "CreateItem" do
            attribute :name, String
          end
        end
      end
      app = boot(domain)

      klass = DoubleDelDomain::Item
      item = klass.create(name: "ephemeral")

      expect { item.destroy }.not_to raise_error
      expect { item.destroy }.not_to raise_error
      expect(klass.count).to eq(0)
    end
  end

  # --- Test 10: Create with extra/unknown attributes ---
  describe "unknown attributes in create" do
    it "passing unknown attributes to create" do
      domain = Hecks.domain("UnknownAttr") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
      app = boot(domain)

      klass = UnknownAttrDomain::Widget

      # Pass an attribute that doesn't exist on the aggregate
      expect {
        klass.create(name: "test", bogus_field: "should this work?")
      }.to raise_error(ArgumentError)
    end
  end

  # --- Test 11: Rapid create/update/delete cycle on same ID ---
  describe "rapid lifecycle on same record" do
    it "create, update 50 times, then delete" do
      domain = Hecks.domain("Lifecycle") do
        aggregate "Counter" do
          attribute :value, Integer
          command "CreateCounter" do
            attribute :value, Integer
          end
        end
      end
      app = boot(domain)

      klass = LifecycleDomain::Counter
      counter = klass.create(value: 0)
      original_id = counter.id

      # Update 50 times
      current = counter
      50.times do |i|
        current = current.update(value: i + 1)
      end

      expect(current.value).to eq(50)
      expect(klass.find(original_id).value).to eq(50)
      expect(klass.count).to eq(1) # should still be just one record

      klass.delete(original_id)
      expect(klass.count).to eq(0)
    end
  end
end
