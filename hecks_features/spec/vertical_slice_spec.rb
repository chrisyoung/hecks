require "spec_helper"
require "hecks_features"

RSpec.describe HecksFeatures::SliceExtractor do
  let(:domain) do
    Hecks.domain("Banking") do
      aggregate "Loan" do
        attribute :amount, Float
        command("IssueLoan") { attribute :amount, Float }
      end

      aggregate "Account" do
        attribute :balance, Float
        command("Deposit") { attribute :amount, Float }
      end

      policy "DisburseFunds" do
        on "IssuedLoan"
        trigger "Deposit"
      end
    end
  end

  let(:slices) { described_class.new(domain).extract }

  it "extracts one slice for the IssueLoan -> Deposit chain" do
    expect(slices.size).to eq(1)
  end

  it "names the slice from the reactive chain" do
    expect(slices.first.name).to include("Issue Loan")
  end

  it "identifies the entry command" do
    expect(slices.first.entry_command).to eq("IssueLoan")
  end

  it "collects participating aggregates" do
    expect(slices.first.aggregates).to contain_exactly("Loan", "Account")
  end

  it "reports cross-aggregate slices" do
    expect(slices.first.cross_aggregate?).to be true
  end

  it "lists commands in the slice" do
    expect(slices.first.commands).to contain_exactly("IssueLoan", "Deposit")
  end

  it "lists events in the slice" do
    expect(slices.first.events).to contain_exactly("IssuedLoan", "Deposited")
  end

  it "lists policies in the slice" do
    expect(slices.first.policies).to eq(["DisburseFunds"])
  end

  it "is not cyclic" do
    expect(slices.first.cyclic).to be false
  end

  context "domain with no reactive policies" do
    let(:domain) do
      Hecks.domain("Simple") do
        aggregate "Widget" do
          attribute :name, String
          command("CreateWidget") { attribute :name, String }
        end
      end
    end

    it "returns no slices" do
      expect(slices).to be_empty
    end
  end

  context "domain with a cycle" do
    let(:domain) do
      Hecks.domain("Cyclic") do
        aggregate "Order" do
          attribute :status, String
          command("PlaceOrder") { attribute :status, String }
          command("ConfirmOrder") { attribute :status, String }
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

    it "detects cycles" do
      expect(slices.first.cyclic).to be true
    end
  end
end

RSpec.describe HecksFeatures::VerticalSlice do
  subject do
    described_class.new(
      name: "Test Slice",
      entry_command: "CreateFoo",
      steps: [
        { type: :command, command: "CreateFoo", aggregate: "Foo", event: "CreatedFoo" },
        { type: :policy, policy: "NotifyBar", event: "CreatedFoo", command: "UpdateBar", aggregate: "Bar" },
        { type: :command, command: "UpdateBar", aggregate: "Bar", event: "UpdatedBar" }
      ],
      aggregates: ["Foo", "Bar"],
      cyclic: false
    )
  end

  it "reports depth as step count" do
    expect(subject.depth).to eq(3)
  end

  it "is cross-aggregate" do
    expect(subject.cross_aggregate?).to be true
  end

  context "single-aggregate slice" do
    subject do
      described_class.new(
        name: "Single", entry_command: "A",
        steps: [{ type: :command, command: "A", aggregate: "X", event: "AEd" }],
        aggregates: ["X"], cyclic: false
      )
    end

    it "is not cross-aggregate" do
      expect(subject.cross_aggregate?).to be false
    end
  end
end
