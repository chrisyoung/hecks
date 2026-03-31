require "spec_helper"

RSpec.describe Hecks::Features::SliceDiagram do
  context "domain with reactive chains" do
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

    let(:diagram) { described_class.new(domain).generate }

    it "starts with flowchart LR" do
      expect(diagram).to start_with("flowchart LR")
    end

    it "contains a subgraph for the slice" do
      expect(diagram).to include("subgraph")
      expect(diagram).to include("end")
    end

    it "renders commands as rectangles" do
      expect(diagram).to include("[IssueLoan]")
      expect(diagram).to include("[Deposit]")
    end

    it "renders events as stadium shapes" do
      expect(diagram).to include("([IssuedLoan])")
    end

    it "renders policies as hexagons" do
      expect(diagram).to include("{{DisburseFunds}}")
    end
  end

  context "domain with no slices" do
    let(:domain) do
      Hecks.domain("Empty") do
        aggregate "Thing" do
          attribute :name, String
          command("CreateThing") { attribute :name, String }
        end
      end
    end

    it "shows a placeholder" do
      diagram = described_class.new(domain).generate
      expect(diagram).to include("No vertical slices found")
    end
  end

  context "domain mixin integration" do
    let(:domain) do
      Hecks.domain("Mix") do
        aggregate "Foo" do
          attribute :x, String
          command("CreateFoo") { attribute :x, String }
        end

        aggregate "Bar" do
          attribute :y, String
          command("UpdateBar") { attribute :y, String }
        end

        policy "TriggerBar" do
          on "CreatedFoo"
          trigger "UpdateBar"
        end
      end
    end

    it "adds slices method to Domain" do
      expect(domain.slices).to be_an(Array)
      expect(domain.slices.first).to be_a(Hecks::Features::VerticalSlice)
    end

    it "adds slices_diagram method to Domain" do
      expect(domain.slices_diagram).to include("flowchart LR")
    end
  end
end
