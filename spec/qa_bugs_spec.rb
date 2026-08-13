require "spec_helper"

# QA BUG DEMONSTRATION SUITE
#
# These tests demonstrate known bugs that have not yet been fixed.
# Tag: qa: true (excluded from normal test runs and CI)
#
# To run only these tests:
#   rspec spec/qa_bugs_spec.rb
#
# To run a specific bug:
#   rspec spec/qa_bugs_spec.rb -e "BUG#7"
#
# When a bug is fixed:
# 1. Remove the qa: true tag
# 2. Move the test to the appropriate spec file
# 3. Verify it passes
# 4. Remove from this file

RSpec.describe "QA Bug Demonstrations", qa: true do
  let(:banking_runtime) { boot_in_memory_for(:banking) }
  let(:till_runtime) { boot_in_memory_for_fixture(:till) }

  def boot_in_memory_for(domain)
    runtime = boot_in_memory
    Hecksagain.with_registry(runtime.registry) do
      Kernel.load(File.join(InMemoryDomain::ROOT, "examples/#{domain}/bluebook/#{domain}.bluebook"))
    end
    runtime
  end

  def boot_in_memory_for_fixture(fixture)
    runtime = boot_in_memory
    Hecksagain.with_registry(runtime.registry) do
      Kernel.load(File.join(InMemoryDomain::ROOT, "spec/fixtures/#{fixture}.bluebook"))
    end
    runtime
  end

  describe "BUG#7: Negative Account Balance Allowed" do


    it "should prevent overdraft (currently fails)" do
      # Create a customer and account
      cust = banking_runtime.dispatch("Banking::Customer.Register",
                                      reference: { value: "cust-#{SecureRandom.hex(4)}" },
                                      name: { given: "John", family: "Doe" },
                                      email: { address: "john@example.com" })

      acct = banking_runtime.dispatch("Banking::Account.Open",
                                      customer_id: cust.id,
                                      number: { value: "acct-#{SecureRandom.hex(4)}" },
                                      kind: { name: "current" },
                                      daily_limit: { cents: 10_000 })

      # Account starts with zero balance
      expect(acct.state[:balance][:cents]).to eq(0)

      # Try to debit more than the balance - should be REFUSED
      expect {
        banking_runtime.dispatch("Banking::Account.Debit",
                                id: acct.id,
                                amount: { cents: 1000, currency: "USD" },
                                narrative: { text: "Overdraft attempt" })
      }.to raise_error(Hecksagain::Runtime::GivenNotMet, /balance|cover/)
    end
  end

  describe "BUG#2: Nested Value Object Invariants Not Validated" do
    it "should enforce nested VO invariants like Price.cents > 0 (currently fails - pending)" do
      # This test demonstrates the architectural bug where nested VO
      # invariants are not validated during coercion.
      # Marked as pending because it requires major refactor to fix.
      pending "Nested VO invariants validation requires coercion.rb refactor"

      # Price invariant says cents must be > 0
      # But when nested in Pizza, it's not validated
      skip "Domain reinitialization issue prevents running"
    end
  end

  describe "BUG#3: Invalid Closed-Set Values Accepted (cascades from BUG#2)" do
    it "should enforce closed-set invariants on nested VOs (currently fails - pending)" do
      # This cascades from BUG#2 - same root cause
      pending "Blocked by BUG#2 - nested VO validation"

      # Size closed set only allows "small" and "large"
      # But "medium" is accepted when nested in Pizza
      skip "Blocked on architectural fix"
    end
  end

  describe "BUG#8: Float Type Coercion Accepted" do
    it "should reject float values for integer cents fields (currently fails)" do
      # Create a customer and account
      cust = banking_runtime.dispatch("Banking::Customer.Register",
                                      reference: { value: "cust-#{SecureRandom.hex(4)}" },
                                      name: { given: "Jane", family: "Doe" },
                                      email: { address: "jane@example.com" })

      acct = banking_runtime.dispatch("Banking::Account.Open",
                                      customer_id: cust.id,
                                      number: { value: "acct-#{SecureRandom.hex(4)}" },
                                      kind: { name: "current" },
                                      daily_limit: { cents: 10_000 })

      # Credit a float amount - should be REJECTED (but currently accepted)
      expect {
        banking_runtime.dispatch("Banking::Account.Credit",
                                id: acct.id,
                                amount: { cents: 12.5, currency: "USD" },
                                narrative: { text: "Float credit" })
      }.to raise_error(Hecksagain::Runtime::TypeMismatch, /Float|numeric|Integer/)
    end
  end

  describe "BUG#9: String Type Coercion Accepted" do
    it "should reject string values for integer cents fields (currently fails)" do
      # Create a customer and account
      cust = banking_runtime.dispatch("Banking::Customer.Register",
                                      reference: { value: "cust-#{SecureRandom.hex(4)}" },
                                      name: { given: "Bob", family: "Smith" },
                                      email: { address: "bob@example.com" })

      acct = banking_runtime.dispatch("Banking::Account.Open",
                                      customer_id: cust.id,
                                      number: { value: "acct-#{SecureRandom.hex(4)}" },
                                      kind: { name: "current" },
                                      daily_limit: { cents: 10_000 })

      # Credit a string amount - should be REJECTED (but currently accepted)
      expect {
        banking_runtime.dispatch("Banking::Account.Credit",
                                id: acct.id,
                                amount: { cents: "1000", currency: "USD" },
                                narrative: { text: "String credit" })
      }.to raise_error(Hecksagain::Runtime::TypeMismatch, /String|numeric|Integer/)
    end
  end

  describe "Banking Domain - Additional Adversarial Tests", qa: true do
    it "rejects empty customer name" do
      expect {
        banking_runtime.dispatch("Banking::Customer.Register",
          reference: { value: "cust-#{SecureRandom.hex(4)}" },
          name: { given: "", family: "Doe" },
          email: { address: "test@example.com" })
      }.to raise_error
    end

    it "rejects empty account number" do
      cust = banking_runtime.dispatch("Banking::Customer.Register",
        reference: { value: "cust-#{SecureRandom.hex(4)}" },
        name: { given: "John", family: "Doe" },
        email: { address: "john@example.com" })

      expect {
        banking_runtime.dispatch("Banking::Account.Open",
          customer_id: cust.id,
          number: { value: "" },
          kind: { name: "current" },
          daily_limit: { cents: 10_000 })
      }.to raise_error
    end

    it "rejects invalid account kind" do
      cust = banking_runtime.dispatch("Banking::Customer.Register",
        reference: { value: "cust-#{SecureRandom.hex(4)}" },
        name: { given: "John", family: "Doe" },
        email: { address: "john@example.com" })

      expect {
        banking_runtime.dispatch("Banking::Account.Open",
          customer_id: cust.id,
          number: { value: "acct-#{SecureRandom.hex(4)}" },
          kind: { name: "invalid_kind" },
          daily_limit: { cents: 10_000 })
      }.to raise_error
    end

    it "rejects negative daily limit" do
      cust = banking_runtime.dispatch("Banking::Customer.Register",
        reference: { value: "cust-#{SecureRandom.hex(4)}" },
        name: { given: "John", family: "Doe" },
        email: { address: "john@example.com" })

      expect {
        banking_runtime.dispatch("Banking::Account.Open",
          customer_id: cust.id,
          number: { value: "acct-#{SecureRandom.hex(4)}" },
          kind: { name: "current" },
          daily_limit: { cents: -1000 })
      }.to raise_error
    end

    it "rejects zero daily limit" do
      cust = banking_runtime.dispatch("Banking::Customer.Register",
        reference: { value: "cust-#{SecureRandom.hex(4)}" },
        name: { given: "John", family: "Doe" },
        email: { address: "john@example.com" })

      expect {
        banking_runtime.dispatch("Banking::Account.Open",
          customer_id: cust.id,
          number: { value: "acct-#{SecureRandom.hex(4)}" },
          kind: { name: "current" },
          daily_limit: { cents: 0 })
      }.to raise_error
    end

    it "rejects empty email address" do
      expect {
        banking_runtime.dispatch("Banking::Customer.Register",
          reference: { value: "cust-#{SecureRandom.hex(4)}" },
          name: { given: "John", family: "Doe" },
          email: { address: "" })
      }.to raise_error
    end

    it "rejects invalid email format" do
      expect {
        banking_runtime.dispatch("Banking::Customer.Register",
          reference: { value: "cust-#{SecureRandom.hex(4)}" },
          name: { given: "John", family: "Doe" },
          email: { address: "not-an-email" })
      }.to raise_error
    end

    it "rejects duplicate account number" do
      cust = banking_runtime.dispatch("Banking::Customer.Register",
        reference: { value: "cust-#{SecureRandom.hex(4)}" },
        name: { given: "John", family: "Doe" },
        email: { address: "john@example.com" })

      acct_num = "acct-#{SecureRandom.hex(4)}"

      banking_runtime.dispatch("Banking::Account.Open",
        customer_id: cust.id,
        number: { value: acct_num },
        kind: { name: "current" },
        daily_limit: { cents: 10_000 })

      expect {
        banking_runtime.dispatch("Banking::Account.Open",
          customer_id: cust.id,
          number: { value: acct_num },
          kind: { name: "current" },
          daily_limit: { cents: 10_000 })
      }.to raise_error
    end

    it "rejects whitespace-only customer reference" do
      expect {
        banking_runtime.dispatch("Banking::Customer.Register",
          reference: { value: "   " },
          name: { given: "John", family: "Doe" },
          email: { address: "john@example.com" })
      }.to raise_error
    end

    it "rejects whitespace-only account number" do
      cust = banking_runtime.dispatch("Banking::Customer.Register",
        reference: { value: "cust-#{SecureRandom.hex(4)}" },
        name: { given: "John", family: "Doe" },
        email: { address: "john@example.com" })

      expect {
        banking_runtime.dispatch("Banking::Account.Open",
          customer_id: cust.id,
          number: { value: "   " },
          kind: { name: "current" },
          daily_limit: { cents: 10_000 })
      }.to raise_error
    end

    it "allows SafeDepositBox with composite identity" do
      box = banking_runtime.dispatch("Banking::SafeDepositBox.Create",
        branch_code: { value: "NYC" },
        box_number: { value: 123 })
      expect(box.id).to_not be_nil
    end

    it "allows same box number in different branches" do
      box1 = banking_runtime.dispatch("Banking::SafeDepositBox.Create",
        branch_code: { value: "NYC" },
        box_number: { value: 123 })

      box2 = banking_runtime.dispatch("Banking::SafeDepositBox.Create",
        branch_code: { value: "LA" },
        box_number: { value: 123 })

      expect(box1.id).not_to eq(box2.id)
    end

    it "rejects duplicate SafeDepositBox" do
      banking_runtime.dispatch("Banking::SafeDepositBox.Create",
        branch_code: { value: "NYC" },
        box_number: { value: 123 })

      expect {
        banking_runtime.dispatch("Banking::SafeDepositBox.Create",
          branch_code: { value: "NYC" },
          box_number: { value: 123 })
      }.to raise_error
    end

    it "rejects empty branch code" do
      expect {
        banking_runtime.dispatch("Banking::SafeDepositBox.Create",
          branch_code: { value: "" },
          box_number: { value: 123 })
      }.to raise_error
    end
  end

  describe "Till Fixture - Adversarial Testing" do
    it "accepts valid till opening" do
      result = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL1" })
      expect(result.state[:number][:value]).to eq("TILL1")
    end

    it "rejects empty till number" do
      expect {
        till_runtime.dispatch("TillRoom::Till.OpenTill",
          number: { value: "" })
      }.to raise_error
    end

    it "rejects whitespace-only till number" do
      expect {
        till_runtime.dispatch("TillRoom::Till.OpenTill",
          number: { value: "   " })
      }.to raise_error
    end

    it "accepts zero amount in TakeIn" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL2" })

      result = till_runtime.dispatch("TillRoom::Till.TakeIn",
        id: till.id,
        amount: { cents: 0 },
        note: nil)

      expect(result.state[:balance][:cents]).to eq(0)
    end

    it "rejects negative amount in TakeIn" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL3" })

      expect {
        till_runtime.dispatch("TillRoom::Till.TakeIn",
          id: till.id,
          amount: { cents: -100 },
          note: nil)
      }.to raise_error
    end

    it "rejects PayOut more than balance" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL4" })

      expect {
        till_runtime.dispatch("TillRoom::Till.PayOut",
          id: till.id,
          amount: { cents: 1000 })
      }.to raise_error
    end

    it "allows Bump command" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL5" })

      result = till_runtime.dispatch("TillRoom::Till.Bump",
        id: till.id)

      expect(result.state[:balance][:cents]).to eq(500)
    end

    it "freezes marks list after TakeIn" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL6" })

      result = till_runtime.dispatch("TillRoom::Till.TakeIn",
        id: till.id,
        amount: { cents: 1000 },
        note: nil)

      expect {
        result.state[:marks] << { amount: 999, direction: "fake" }
      }.to raise_error(FrozenError)
    end

    it "allows multiple TakeIn operations" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL7" })

      till_runtime.dispatch("TillRoom::Till.TakeIn",
        id: till.id,
        amount: { cents: 1000 },
        note: nil)

      result = till_runtime.dispatch("TillRoom::Till.TakeIn",
        id: till.id,
        amount: { cents: 500 },
        note: nil)

      expect(result.state[:balance][:cents]).to eq(1500)
    end

    it "rejects negative amount in PayOut" do
      till = till_runtime.dispatch("TillRoom::Till.OpenTill",
        number: { value: "TILL8" })

      till_runtime.dispatch("TillRoom::Till.TakeIn",
        id: till.id,
        amount: { cents: 1000 },
        note: nil)

      expect {
        till_runtime.dispatch("TillRoom::Till.PayOut",
          id: till.id,
          amount: { cents: -500 })
      }.to raise_error
    end
  end

end
