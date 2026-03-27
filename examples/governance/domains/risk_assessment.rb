require "date"

Hecks.domain "RiskAssessment" do
  aggregate "Assessment" do
    attribute :model_id, String
    attribute :assessor_id, String
    attribute :risk_level, String, enum: %w[low medium high critical]
    attribute :bias_score, Float
    attribute :safety_score, Float
    attribute :transparency_score, Float
    attribute :overall_score, Float
    attribute :submitted_at, DateTime
    attribute :findings, list_of("Finding")
    attribute :mitigations, list_of("Mitigation")

    attribute :status, String
    lifecycle :status, default: "pending" do
      transition "InitiateAssessment" => "pending"
      transition "SubmitAssessment"   => "submitted", from: "pending"
      transition "RejectAssessment"   => "rejected",  from: ["pending", "submitted"]
    end

    value_object "Finding" do
      attribute :category, String
      attribute :severity, String, enum: %w[low medium high critical]
      attribute :description, String
    end

    value_object "Mitigation" do
      attribute :finding_category, String
      attribute :action, String
      attribute :status, String
    end

    validation :model_id, presence: true
    validation :assessor_id, presence: true

    invariant "scores must be between 0 and 1" do
      [bias_score, safety_score, transparency_score, overall_score].all? { |s|
        s.nil? || (s >= 0.0 && s <= 1.0)
      }
    end

    command "InitiateAssessment" do
      attribute :model_id, String
      attribute :assessor_id, String
      actor "assessor"
      actor "admin"
    end

    command "RecordFinding" do
      attribute :assessment_id, String
      attribute :category, String
      attribute :severity, String
      attribute :description, String
      actor "assessor"
      actor "admin"
    end

    command "SubmitAssessment" do
      attribute :assessment_id, String
      attribute :risk_level, String
      attribute :bias_score, Float
      attribute :safety_score, Float
      attribute :transparency_score, Float
      attribute :overall_score, Float
      sets submitted_at: :now
      actor "assessor"
      actor "admin"
    end

    command "RejectAssessment" do
      attribute :assessment_id, String
      actor "governance_board"
      actor "admin"
    end

    specification "CriticalFindings" do |assessment|
      assessment.findings.any? { |f| f.severity == "critical" }
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "Pending" do
      where(status: "pending")
    end
  end
end
