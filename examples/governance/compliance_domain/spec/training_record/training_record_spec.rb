require "spec_helper"

RSpec.describe ComplianceDomain::TrainingRecord do
  describe "creating a TrainingRecord" do
    subject(:training_record) { described_class.new(
          stakeholder_id: "example",
          policy_id: "example",
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example"
        ) }

    it "assigns an id" do
      expect(training_record.id).not_to be_nil
    end

    it "sets stakeholder_id" do
      expect(training_record.stakeholder_id).to eq("example")
    end

    it "sets policy_id" do
      expect(training_record.policy_id).to eq("example")
    end

    it "sets completed_at" do
      expect(training_record.completed_at).not_to be_nil
    end

    it "sets expires_at" do
      expect(training_record.expires_at).not_to be_nil
    end

    it "sets certification_id" do
      expect(training_record.certification_id).to eq("example")
    end

    it "sets status" do
      expect(training_record.status).to eq("example")
    end
  end

  describe "stakeholder_id validation" do
    it "rejects nil stakeholder_id" do
      expect {
        described_class.new(
          stakeholder_id: nil,
          policy_id: "example",
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example"
        )
      }.to raise_error(ComplianceDomain::ValidationError, /stakeholder_id/)
    end
  end

  describe "policy_id validation" do
    it "rejects nil policy_id" do
      expect {
        described_class.new(
          stakeholder_id: "example",
          policy_id: nil,
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example"
        )
      }.to raise_error(ComplianceDomain::ValidationError, /policy_id/)
    end
  end

  describe "invariant: expires_at must be after completed_at" do
    it "raises InvariantError when violated" do
      # TODO: construct an instance that violates: expires_at must be after completed_at
      # expect { described_class.new(...) }.to raise_error(ComplianceDomain::InvariantError)
    end
  end

  describe "identity" do
    it "two TrainingRecords with the same id are equal" do
      id = SecureRandom.uuid
      a = described_class.new(
          stakeholder_id: "example",
          policy_id: "example",
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example",
          id: id
        )
      b = described_class.new(
          stakeholder_id: "example",
          policy_id: "example",
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example",
          id: id
        )
      expect(a).to eq(b)
    end

    it "two TrainingRecords with different ids are not equal" do
      a = described_class.new(
          stakeholder_id: "example",
          policy_id: "example",
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example"
        )
      b = described_class.new(
          stakeholder_id: "example",
          policy_id: "example",
          completed_at: DateTime.now,
          expires_at: Date.today,
          certification_id: "example",
          status: "example"
        )
      expect(a).not_to eq(b)
    end
  end
end
