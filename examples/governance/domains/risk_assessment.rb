require "date"

Hecks.domain "RiskAssessment" do
  Assessment do
    model_id String
    assessor_id String
    risk_level String, enum: %w[low medium high critical]
    bias_score Float
    safety_score Float
    transparency_score Float
    overall_score Float
    submitted_at DateTime
    findings list_of("Finding")
    mitigations list_of("Mitigation")

    status String
    lifecycle :status, default: "pending" do
      transition "InitiateAssessment" => "pending"
      transition "SubmitAssessment"   => "submitted", from: "pending"
      transition "RejectAssessment"   => "rejected",  from: ["pending", "submitted"]
    end

    Finding do
      category String
      severity String, enum: %w[low medium high critical]
      description String
    end

    Mitigation do
      finding_category String
      action String
      status String
    end

    validation :model_id, presence: true
    validation :assessor_id, presence: true

    invariant "scores must be between 0 and 1" do
      [bias_score, safety_score, transparency_score, overall_score].all? { |s|
        s.nil? || (s >= 0.0 && s <= 1.0)
      }
    end

    initiate_assessment do
      model_id String
      assessor_id String
      actor "assessor"
      actor "admin"
    end

    record_finding do
      assessment_id String
      category String
      severity String
      description String
      actor "assessor"
      actor "admin"
    end

    submit_assessment do
      assessment_id String
      risk_level String
      bias_score Float
      safety_score Float
      transparency_score Float
      overall_score Float
      sets submitted_at: :now
      actor "assessor"
      actor "admin"
    end

    reject_assessment do
      assessment_id String
      actor "governance_board"
      actor "admin"
    end

    specification "CriticalFindings" do |assessment|
      assessment.findings.any? { |f| f.severity == "critical" }
    end

    query :by_model do |model_id|
      where(model_id: model_id)
    end

    query :pending do
      where(status: "pending")
    end
  end
end
