Hecks.domain "RiskAssessment" do
  actor "assessor", description: "Risk assessment specialist"
  actor "governance_board", description: "Final approval authority"
  actor "admin", description: "System administrator"

  aggregate "Assessment" do
    reference_to "ModelRegistry::AiModel", as: :model
    reference_to "Identity::Stakeholder", as: :assessor
    attribute :risk_level, String
    attribute :bias_score, Float
    attribute :safety_score, Float
    attribute :transparency_score, Float
    attribute :overall_score, Float
    attribute :submitted_at, DateTime
    attribute :findings, list_of("Finding")
    attribute :mitigations, list_of("Mitigation")
    attribute :status, String

    value_object "Finding" do
      attribute :category, String
      attribute :severity, String
      attribute :description, String
    end

    value_object "Mitigation" do
      attribute :finding_category, String
      attribute :action, String
      attribute :status, String
    end

    validation :model_id, {:presence=>true}

    validation :assessor_id, {:presence=>true}

    invariant "scores must be between 0 and 1" do
      [bias_score, safety_score, transparency_score, overall_score].all? { |s|
s.nil? || (s >= 0.0 && s <= 1.0)
}
    end

    query "ByModel" do
      where(model_id: model_id)
    end

    query "Pending" do
      where(status: "pending")
    end

    specification "CriticalFindings" do |assessment|
      assessment.findings.any? { |f| f.severity == "critical" }
    end

    command "InitiateAssessment" do
      attribute :model_id, reference_to("AiModel")
      attribute :assessor_id, reference_to("Stakeholder")
      actor "assessor"
      actor "admin"
    end

    command "RecordFinding" do
      attribute :assessment_id, reference_to("Assessment")
      attribute :category, String
      attribute :severity, String
      attribute :description, String
      actor "assessor"
      actor "admin"
    end

    command "SubmitAssessment" do
      attribute :assessment_id, reference_to("Assessment")
      attribute :risk_level, String
      attribute :bias_score, Float
      attribute :safety_score, Float
      attribute :transparency_score, Float
      attribute :overall_score, Float
      actor "assessor"
      actor "admin"
    end

    command "RejectAssessment" do
      attribute :assessment_id, reference_to("Assessment")
      actor "governance_board"
      actor "admin"
    end
  end
end
