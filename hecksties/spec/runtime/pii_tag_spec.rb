require "spec_helper"
require "hecks/extensions/pii"

RSpec.describe "PII attribute tag via hecksagon capabilities" do
  let(:domain) do
    Hecks.domain "PiiTagTest" do
      aggregate "Customer" do
        attribute :name, String
        attribute :email, String
        attribute :ssn, String
        attribute :account_type, String

        command "RegisterCustomer" do
          attribute :name, String
          attribute :email, String
          attribute :ssn, String
          attribute :account_type, String
        end
      end
    end
  end

  let(:hecksagon_ir) do
    Hecks.hecksagon do
      capabilities "Customer" do
        email.privacy
        ssn.privacy
      end
    end
  end

  let(:runtime) do
    Hecks.load(domain, hecksagon: hecksagon_ir)
  end

  let(:customer_class) do
    runtime
    Object.const_get("PiiTagTestDomain::Customer")
  end

  describe "inspect redaction" do
    it "masks PII attributes in inspect output" do
      customer = customer_class.create(
        name: "Alice", email: "alice@example.com",
        ssn: "123-45-6789", account_type: "premium"
      )
      output = customer.inspect
      expect(output).not_to include("alice@example.com")
      expect(output).not_to include("123-45-6789")
      expect(output).to include("premium")
    end
  end

  describe "pii_report" do
    it "returns a hash of aggregate to PII attributes" do
      report = runtime.pii_report
      expect(report).to eq("Customer" => ["email", "ssn"])
    end
  end

  describe "non-PII attributes" do
    it "are not marked as PII on the runtime definition" do
      account_attr = customer_class.hecks_attributes.find { |a| a.name == :account_type }
      expect(account_attr.pii).to be_falsy
    end
  end

  describe "PII attributes" do
    it "are marked as PII on the runtime definition" do
      email_attr = customer_class.hecks_attributes.find { |a| a.name == :email }
      expect(email_attr.pii).to eq(true)
    end
  end
end
