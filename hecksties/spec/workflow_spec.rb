require "spec_helper"

RSpec.describe "Workflow Engine (HEC-163)" do
  let(:domain) do
    Hecks.domain "WorkflowTest" do
      aggregate "Loan" do
        attribute :principal, Float
        attribute :status, String

        command "ScoreLoan" do
          attribute :principal, Float
        end

        command "ApproveLoan" do
          attribute :principal, Float
        end

        command "ReviewLoan" do
          attribute :principal, Float
        end

        specification "HighRisk" do |obj|
          obj.principal.to_f > 50_000
        end
      end

      workflow "LoanApproval" do
        step "ScoreLoan"
        branch do
          when_spec("HighRisk") { step "ReviewLoan" }
          otherwise { step "ApproveLoan" }
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain)
  end


  it "registers workflows in the domain IR" do
    expect(domain.workflows.size).to eq(1)
    wf = domain.workflows.first
    expect(wf.name).to eq("LoanApproval")
    expect(wf.steps.size).to eq(2)
    expect(wf.steps.first.command).to eq("ScoreLoan")
    expect(wf.steps.last).to be_a(Hecks::DomainModel::Behavior::BranchStep)
  end

  it "exposes workflow as a callable method on the domain module" do
    expect(WorkflowTestDomain).to respond_to(:loan_approval)
  end

  it "executes the else branch for low-risk loans" do
    # principal 1000 < 50_000 => HighRisk not satisfied => else => ApproveLoan
    result = WorkflowTestDomain.loan_approval(principal: 1000.0)
    # Result is the event from the last command (ApprovedLoan)
    expect(result.class.name).to include("ApprovedLoan")
  end

  it "executes the if branch for high-risk loans" do
    # principal 80_000 > 50_000 => HighRisk satisfied => if => ReviewLoan
    result = WorkflowTestDomain.loan_approval(principal: 80_000.0)
    expect(result.class.name).to include("ReviewedLoan")
  end
end
