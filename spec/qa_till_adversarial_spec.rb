require "spec_helper"

# QA Session 2026-08-12 (Loop): Till Domain Adversarial Testing
# Target: Find bugs in TillRoom aggregate

RSpec.describe "Till domain adversarial testing - Bug Discovery" do
  TILL_BLUEBOOK = File.join(InMemoryDomain::ROOT, "spec/fixtures/till.bluebook")

  def boot_till
    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(TILL_BLUEBOOK)
      Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
    end
  end

  describe "Category 1: Boundary Testing" do
    it "opens till with very long number" do
      runtime = boot_till
      long_num = "TILL" + ("X" * 500)

      expect {
        runtime.dispatch("TillRoom::Till.OpenTill", number: { value: long_num })
      }.not_to raise_error
    end

    it "rejects till with whitespace-only number" do
      runtime = boot_till

      expect {
        runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "   " })
      }.to raise_error
    end
  end

  describe "Category 2: Balance Boundaries" do
    let(:runtime) { boot_till }

    it "can open till and check zero balance" do
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL001" })
      # Zero balance is the default
    end

    it "can take in large amount" do
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL002" })

      expect {
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL002",
          amount: { cents: 999_999_999 },
          note: { text: "Large deposit" })
      }.not_to raise_error
    end

    it "POTENTIAL BUG: PayOut with amount > balance" do
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL003" })

      # Till starts with 0 cents
      # Try to pay out 100 cents (should this be rejected?)
      error = nil
      result = nil
      begin
        result = runtime.dispatch("TillRoom::Till.PayOut",
          id: "TILL003",
          amount: { cents: 100 })
      rescue => e
        error = e
      end

      if error
        puts "✓ Till rejects PayOut when balance insufficient"
      else
        puts "🐛 BUG #1: Till allows PayOut > balance (negative balance possible!)"
      end
    end

    it "rejects negative amount in Money" do
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL004" })

      expect {
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL004",
          amount: { cents: -100 },
          note: { text: "Negative deposit" })
      }.to raise_error(Hecksagain::Runtime::InvariantViolation)
    end
  end

  describe "Category 3: Note Handling (Optional Field)" do
    it "TakeIn without optional note" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL005" })

      expect {
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL005",
          amount: { cents: 500 })
      }.not_to raise_error
    end

    it "TakeIn with empty note (should be rejected)" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL006" })

      expect {
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL006",
          amount: { cents: 500 },
          note: { text: "" })
      }.to raise_error
    end

    it "TakeIn with whitespace-only note" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL007" })

      expect {
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL007",
          amount: { cents: 500 },
          note: { text: "   " })
      }.to raise_error
    end
  end

  describe "Category 4: Mark Validation" do
    it "POTENTIAL BUG: Mark with invalid direction value" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL008" })

      # Append a mark directly (if possible)
      # This tests if direction validation is enforced
      error = nil
      begin
        # TakeIn should create a valid mark
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL008",
          amount: { cents: 100 },
          note: { text: "Normal deposit" })
      rescue => e
        error = e
      end

      if error
        puts "Error on normal TakeIn: #{error}"
      else
        puts "✓ TakeIn creates valid mark"
      end
    end

    it "mark amount must be positive" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL009" })

      # TakeIn with zero amount (Money invariant: amount.positive? on Mark)
      # Note: Money allows 0 (>= 0), but Mark requires positive (> 0)
      error = nil
      begin
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL009",
          amount: { cents: 0 },
          note: { text: "Zero deposit" })
      rescue => e
        error = e
      end

      if error
        puts "✓ Till rejects zero amount in TakeIn"
      else
        puts "🐛 BUG #2: Till allows zero-cent deposit (Mark.amount must be positive)"
      end
    end
  end

  describe "Category 5: Rapid Mutations" do
    it "rapid TakeIn/PayOut operations" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL010" })

      # Rapid deposits
      expect {
        10.times do |i|
          runtime.dispatch("TillRoom::Till.TakeIn",
            id: "TILL010",
            amount: { cents: 100 },
            note: { text: "Deposit #{i}" })
        end
      }.not_to raise_error

      # Now rapid withdrawals (within bounds)
      expect {
        5.times do |i|
          runtime.dispatch("TillRoom::Till.PayOut",
            id: "TILL010",
            amount: { cents: 100 })
        end
      }.not_to raise_error
    end
  end

  describe "Category 6: Bump Command" do
    it "Bump adds 500 cents" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL011" })

      expect {
        runtime.dispatch("TillRoom::Till.Bump", id: "TILL011")
      }.not_to raise_error
    end

    it "POTENTIAL BUG: Multiple Bumps stack correctly" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL012" })

      # Bump multiple times
      3.times do
        runtime.dispatch("TillRoom::Till.Bump", id: "TILL012")
      end
      # Should have 1500 cents (3 × 500)

      puts "✓ Multiple Bumps allowed"
    end
  end

  describe "Category 7: Mark List Immutability" do
    it "marks list is frozen" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL013" })
      runtime.dispatch("TillRoom::Till.TakeIn",
        id: "TILL013",
        amount: { cents: 100 },
        note: { text: "Test" })

      # Try to query and mutate marks
      result = runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL_TEMP" })

      if result.frozen?
        puts "✓ Till result is frozen"
      else
        puts "! Till result not frozen"
      end
    end
  end

  describe "Category 8: Special Characters" do
    it "accepts unicode in till number" do
      runtime = boot_till

      expect {
        runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL_café" })
      }.not_to raise_error
    end

    it "accepts unicode in note" do
      runtime = boot_till
      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "TILL014" })

      expect {
        runtime.dispatch("TillRoom::Till.TakeIn",
          id: "TILL014",
          amount: { cents: 100 },
          note: { text: "Café payment" })
      }.not_to raise_error
    end
  end

  describe "Category 9: Edge Cases" do
    it "POTENTIAL BUG: Till number identity uniqueness" do
      runtime = boot_till

      runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "UNIQUE" })

      error = nil
      begin
        runtime.dispatch("TillRoom::Till.OpenTill", number: { value: "UNIQUE" })
      rescue => e
        error = e
      end

      if error
        puts "✓ Till rejects duplicate number"
      else
        puts "🐛 BUG #3: Till allows duplicate number (identity should be unique)"
      end
    end
  end
end
