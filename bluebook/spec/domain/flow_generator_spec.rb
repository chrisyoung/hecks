require "spec_helper"

RSpec.describe Hecks::FlowGenerator do
  def build_banking_domain
    Hecks.domain "Banking" do
      aggregate "Customer" do
        attribute :name, String
        attribute :status, String, default: "active"

        command "RegisterCustomer" do
          attribute :name, String
        end

        command "SuspendCustomer" do
          attribute :customer_id, String
        end
      end

      aggregate "Account" do
        attribute :balance, Float

        command "OpenAccount" do
          attribute :account_type, String
        end

        command "Deposit" do
          attribute :amount, Float
        end

        command "Withdraw" do
          attribute :amount, Float
        end
      end

      aggregate "Loan" do
        attribute :principal, Float

        command "IssueLoan" do
          attribute :principal, Float
          attribute :account_id, String
        end

        command "DefaultLoan" do
          attribute :loan_id, String
          attribute :customer_id, String
        end
      end

      policy "DisburseFunds" do
        on "IssuedLoan"
        trigger "Deposit"
        map account_id: :account_id, principal: :amount
      end

      policy "SuspendOnDefault" do
        on "DefaultedLoan"
        trigger "SuspendCustomer"
        map customer_id: :customer_id
      end
    end
  end

  describe "#generate_text" do
    it "produces flow descriptions for reactive chains" do
      domain = build_banking_domain
      text = described_class.new(domain).generate_text

      expect(text).to include("Flow:")
      expect(text).to include("IssueLoan")
      expect(text).to include("IssuedLoan")
      expect(text).to include("[Policy: DisburseFunds]")
      expect(text).to include("Deposit")
    end

    it "traces the default -> suspend chain" do
      domain = build_banking_domain
      text = described_class.new(domain).generate_text

      expect(text).to include("DefaultLoan")
      expect(text).to include("DefaultedLoan")
      expect(text).to include("[Policy: SuspendOnDefault]")
      expect(text).to include("SuspendCustomer")
    end

    it "returns a message when no flows exist" do
      domain = Hecks.domain "Empty" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      text = described_class.new(domain).generate_text
      expect(text).to eq("No reactive flows found.")
    end
  end

  describe "#generate_mermaid" do
    it "produces a Mermaid sequence diagram" do
      domain = build_banking_domain
      mermaid = described_class.new(domain).generate_mermaid

      expect(mermaid).to start_with("sequenceDiagram")
      expect(mermaid).to include("participant Loan")
      expect(mermaid).to include("participant Account")
      expect(mermaid).to include("IssueLoan")
      expect(mermaid).to include("DisburseFunds")
    end

    it "returns a minimal diagram when no flows exist" do
      domain = Hecks.domain "Empty" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      mermaid = described_class.new(domain).generate_mermaid
      expect(mermaid).to include("No reactive flows")
    end
  end

  describe "cycle detection" do
    it "detects and marks cyclic flows" do
      domain = Hecks.domain "Cyclic" do
        aggregate "Order" do
          attribute :status, String

          command "PlaceOrder" do
            attribute :item, String
          end

          command "ConfirmOrder" do
            attribute :order_id, String
          end

          policy "AutoConfirm" do
            on "PlacedOrder"
            trigger "ConfirmOrder"
          end

          policy "ReOrder" do
            on "ConfirmedOrder"
            trigger "PlaceOrder"
          end
        end
      end

      text = described_class.new(domain).generate_text
      expect(text).to include("[CYCLIC]")
      expect(text).to include("[CYCLE]")
    end
  end

  describe "Domain#describe integration" do
    it "includes reactive flows in describe output" do
      domain = build_banking_domain
      output = capture_stdout { domain.describe }

      expect(output).to include("Reactive Flows:")
      expect(output).to include("IssueLoan")
      expect(output).to include("DisburseFunds")
    end
  end

  describe "Domain convenience methods" do
    it "exposes flows via Domain#flows" do
      domain = build_banking_domain
      expect(domain.flows).to include("Flow:")
    end

    it "exposes Mermaid via Domain#flows_mermaid" do
      domain = build_banking_domain
      expect(domain.flows_mermaid).to start_with("sequenceDiagram")
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
