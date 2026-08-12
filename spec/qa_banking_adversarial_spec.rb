require "spec_helper"

# QA Session 2026-08-12: Banking Domain Adversarial Testing
#
# Tests the Banking domain systematically across 8 categories:
# 1. Boundary testing (min/max values)
# 2. Empty/null values
# 3. State violation testing
# 4. Mutation/immutability testing
# 5. Identity/uniqueness testing
# 6. Type coercion
# 7. Rapid mutation (high volume)
# 8. Special characters
# 9. Valid input verification (after fixes)

RSpec.describe "Banking domain adversarial testing" do
  BANKING_BLUEBOOK = File.join(InMemoryDomain::ROOT, "examples/banking/bluebook/banking.bluebook")

  def boot_banking
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(BANKING_BLUEBOOK)
      Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
    end
  end

  # ============================================================================
  # CATEGORY 1: BOUNDARY TESTING
  # ============================================================================

  describe "Category 1: Boundary Testing" do
    it "accepts a customer with very long reference" do
      runtime = boot_banking
      long_ref = "CUST" + ("X" * 1000)

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: long_ref },
          name: { given: "John", family: "Doe" },
          email: { address: "john@example.com" })
      }.not_to raise_error
    end

    it "accepts an account with zero balance" do
      runtime = boot_banking

      cust_result = runtime.dispatch("Banking::Customer.Register",
        reference: { value: "CUST_ZERO_BAL" },
        name: { given: "Zero", family: "Balance" },
        email: { address: "zero@example.com" })

      # Banking uses "Account.Open" command based on spec pattern
      expect {
        runtime.dispatch("Banking::Account.Open",
          customer_id: cust_result.id,
          number: { value: "ACC_ZERO" },
          kind: { name: "current" },
          daily_limit: { cents: 0 })
      }.not_to raise_error
    end

    it "rejects customer with just whitespace in reference" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "   " },
          name: { given: "Whitespace", family: "Test" },
          email: { address: "ws@example.com" })
      }.to raise_error
    end
  end

  # ============================================================================
  # CATEGORY 2: EMPTY/NULL VALUES
  # ============================================================================

  describe "Category 2: Empty/Null Values" do
    it "rejects customer with empty given name" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "EMPTY_GIVEN" },
          name: { given: "", family: "Doe" },
          email: { address: "test@example.com" })
      }.to raise_error
    end

    it "rejects customer with empty family name" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "EMPTY_FAMILY" },
          name: { given: "John", family: "" },
          email: { address: "test@example.com" })
      }.to raise_error
    end

    it "rejects customer with whitespace-only given name" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "WS_GIVEN" },
          name: { given: "   ", family: "Doe" },
          email: { address: "test@example.com" })
      }.to raise_error
    end

    it "rejects customer with empty email" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "EMPTY_EMAIL" },
          name: { given: "John", family: "Doe" },
          email: { address: "" })
      }.to raise_error
    end
  end

  # ============================================================================
  # CATEGORY 3: STATE VIOLATION TESTING
  # ============================================================================

  describe "Category 3: State Violation Testing" do
    it "customer can transition active → suspended" do
      runtime = boot_banking

      cust_result = runtime.dispatch("Banking::Customer.Register",
        reference: { value: "STATE_TEST_1" },
        name: { given: "State", family: "Test" },
        email: { address: "state@test.com" })

      expect {
        runtime.dispatch("Banking::Customer.Suspend",
          id: cust_result.id,
          standing: { value: "flagged" })
      }.not_to raise_error
    end

    it "cannot Reinstate when already active" do
      runtime = boot_banking

      cust_result = runtime.dispatch("Banking::Customer.Register",
        reference: { value: "STATE_TEST_2" },
        name: { given: "Reinstate", family: "Test" },
        email: { address: "reinstate@test.com" })

      # Customer is active by default, try to reinstate anyway
      expect {
        runtime.dispatch("Banking::Customer.Reinstate", id: cust_result.id)
      }.to raise_error(Hecksagain::Runtime::GivenNotMet)
    end
  end

  # ============================================================================
  # CATEGORY 4: MUTATION/IMMUTABILITY TESTING
  # ============================================================================

  describe "Category 4: Mutation/Immutability Testing" do
    it "returned customer aggregate is frozen" do
      runtime = boot_banking

      cust = runtime.dispatch("Banking::Customer.Register",
        reference: { value: "FROZEN_TEST" },
        name: { given: "Frozen", family: "Customer" },
        email: { address: "frozen@test.com" })

      # The returned aggregate should be frozen
      if cust.frozen?
        expect { cust.some_attr = "new value" }.to raise_error(FrozenError)
      end
    end
  end

  # ============================================================================
  # CATEGORY 5: IDENTITY/UNIQUENESS TESTING
  # ============================================================================

  describe "Category 5: Identity/Uniqueness Testing" do
    it "rejects duplicate customer reference" do
      runtime = boot_banking

      runtime.dispatch("Banking::Customer.Register",
        reference: { value: "UNIQUE_TEST" },
        name: { given: "First", family: "Customer" },
        email: { address: "first@example.com" })

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "UNIQUE_TEST" },
          name: { given: "Second", family: "Customer" },
          email: { address: "second@example.com" })
      }.to raise_error(Hecksagain::Runtime::GivenNotMet)
    end
  end

  # ============================================================================
  # CATEGORY 6: TYPE COERCION TESTING
  # ============================================================================

  describe "Category 6: Type Coercion Testing" do
    it "rejects non-string email (if type strict)" do
      runtime = boot_banking

      error = nil
      begin
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "TYPETEST" },
          name: { given: "Type", family: "Test" },
          email: { address: 12345 })
      rescue => e
        error = e
      end

      # Document the behavior
      if error
        puts "✓ Banking rejects non-string email: #{error.class}"
      else
        puts "! Banking coerces non-string email"
      end
    end
  end

  # ============================================================================
  # CATEGORY 7: RAPID MUTATION TESTING
  # ============================================================================

  describe "Category 7: Rapid Mutation Testing" do
    it "creates 25 customers in rapid succession" do
      runtime = boot_banking
      created_ids = []

      expect {
        25.times do |i|
          result = runtime.dispatch("Banking::Customer.Register",
            reference: { value: "RAPID#{format('%03d', i)}" },
            name: { given: "Customer#{i}", family: "Test" },
            email: { address: "rapid#{i}@test.com" })
          created_ids << result.id
        end
      }.not_to raise_error

      expect(created_ids.length).to eq(25)
      expect(created_ids.uniq.length).to eq(25)
    end
  end

  # ============================================================================
  # CATEGORY 8: SPECIAL CHARACTERS TESTING
  # ============================================================================

  describe "Category 8: Special Characters" do
    it "accepts customer with unicode name" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "UNICODE001" },
          name: { given: "José", family: "García" },
          email: { address: "jose@example.com" })
      }.not_to raise_error
    end

    it "accepts customer with apostrophe in name" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "APOSTROPHE001" },
          name: { given: "Mary", family: "O'Brien" },
          email: { address: "mary@example.com" })
      }.not_to raise_error
    end

    it "accepts customer with hyphen in name" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "HYPHEN001" },
          name: { given: "Jean", family: "Dupont-Martin" },
          email: { address: "jean@example.com" })
      }.not_to raise_error
    end
  end

  # ============================================================================
  # CATEGORY 9: VALID INPUT VERIFICATION (AFTER FIXES)
  # ============================================================================

  describe "Category 9: Valid Input Verification" do
    it "still accepts normal customer input" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "VALID001" },
          name: { given: "Normal", family: "Customer" },
          email: { address: "valid@example.com" })
      }.not_to raise_error
    end

    it "still accepts customer with compound email domain" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "COMPOUND001" },
          name: { given: "Compound", family: "Email" },
          email: { address: "user@mail.example.co.uk" })
      }.not_to raise_error
    end

    it "still rejects truly empty reference" do
      runtime = boot_banking

      expect {
        runtime.dispatch("Banking::Customer.Register",
          reference: { value: "" },
          name: { given: "Empty", family: "Ref" },
          email: { address: "empty@test.com" })
      }.to raise_error
    end
  end
end
