Hecks.domain "Compliance" do
  uses_kernel "Identity"

  driving_port :http, description: "REST API"
  driving_port :events, description: "Cross-domain event bus"

  driven_port :persistence, [:find, :save, :delete, :all]
  driven_port :notifications, [:send_email], description: "Policy change alerts"

  actor "governance_board", description: "Policy oversight committee"
  actor "reviewer", description: "Compliance reviewer"
  actor "admin", description: "System administrator"

  anti_corruption_layer "ModelRegistry" do
    translate "AiModel", model_name: :name, model_version: :version
  end

  published_event "ReviewCompleted", version: 1 do
    attribute :review_id, String
    attribute :model_id, String
    attribute :outcome, String
  end

  saga "ComplianceCheck" do
    step "OpenReview", on_success: "ApproveReview", on_failure: "RejectReview"
    step "RejectReview", on_success: "SuspendModel"
    compensation "SuspendModel"
  end

  aggregate "GovernancePolicy" do
    attribute :name, String
    attribute :description, String
    attribute :category, String
    reference_to "RegulatoryFramework"
    attribute :effective_date, Date
    attribute :review_date, Date
    attribute :requirements, list_of("Requirement")
    attribute :status, String

    value_object "Requirement" do
      attribute :description, String
      attribute :priority, String
      attribute :category, String
    end

    validation :name, {:presence=>true}

    validation :category, {:presence=>true}

    query "ByCategory" do
      where(category: category)
    end

    query "ByFramework" do
      where(framework_id: framework_id)
    end

    query "Active" do
      where(status: "active")
    end

    command "CreatePolicy" do
      attribute :name, String
      attribute :description, String
      attribute :category, String
      attribute :framework_id, reference_to("RegulatoryFramework")
      actor "governance_board"
      actor "admin"
    end

    command "ActivatePolicy" do
      attribute :policy_id, reference_to("GovernancePolicy")
      attribute :effective_date, Date
      actor "governance_board"
      actor "admin"
    end

    command "SuspendPolicy" do
      attribute :policy_id, reference_to("GovernancePolicy")
      actor "governance_board"
      actor "admin"
    end

    command "RetirePolicy" do
      attribute :policy_id, reference_to("GovernancePolicy")
      actor "governance_board"
      actor "admin"
    end

    command "UpdateReviewDate" do
      attribute :policy_id, reference_to("GovernancePolicy")
      attribute :review_date, Date
      actor "governance_board"
      actor "admin"
    end
  end

  aggregate "RegulatoryFramework" do
    attribute :name, String
    attribute :jurisdiction, String
    attribute :version, String
    attribute :effective_date, Date
    attribute :authority, String
    attribute :requirements, list_of("FrameworkRequirement")
    attribute :status, String

    value_object "FrameworkRequirement" do
      attribute :article, String
      attribute :section, String
      attribute :description, String
      attribute :risk_category, String
    end

    validation :name, {:presence=>true}

    validation :jurisdiction, {:presence=>true}

    query "ByJurisdiction" do
      where(jurisdiction: jurisdiction)
    end

    query "Active" do
      where(status: "active")
    end

    command "RegisterFramework" do
      attribute :name, String
      attribute :jurisdiction, String
      attribute :version, String
      attribute :authority, String
    end

    command "ActivateFramework" do
      attribute :framework_id, reference_to("RegulatoryFramework")
      attribute :effective_date, Date
    end

    command "RetireFramework" do
      attribute :framework_id, reference_to("RegulatoryFramework")
    end
  end

  aggregate "ComplianceReview" do
    reference_to "ModelRegistry::AiModel", as: :model
    reference_to "GovernancePolicy", as: :policy
    reference_to "Identity::Stakeholder", as: :reviewer
    attribute :outcome, String
    attribute :notes, String
    attribute :completed_at, DateTime
    attribute :conditions, list_of("ReviewCondition")
    attribute :status, String

    value_object "ReviewCondition" do
      attribute :requirement, String
      attribute :met, String
      attribute :evidence, String
    end

    validation :model_id, {:presence=>true}

    validation :reviewer_id, {:presence=>true}

    query "ByModel" do
      where(model_id: model_id)
    end

    query "Pending" do
      where(status: "open")
    end

    query "ByReviewer" do
      where(reviewer_id: reviewer_id)
    end

    command "OpenReview" do
      attribute :model_id, reference_to("AiModel")
      attribute :policy_id, reference_to("GovernancePolicy")
      attribute :reviewer_id, reference_to("Stakeholder")
      actor "reviewer"
      actor "admin"
    end

    command "ApproveReview" do
      attribute :review_id, reference_to("ComplianceReview")
      attribute :notes, String
      actor "reviewer"
      actor "admin"
    end

    command "RejectReview" do
      attribute :review_id, reference_to("ComplianceReview")
      attribute :notes, String
      actor "reviewer"
      actor "admin"
    end

    command "RequestChanges" do
      attribute :review_id, reference_to("ComplianceReview")
      attribute :notes, String
      actor "reviewer"
      actor "admin"
    end
  end

  aggregate "Exemption" do
    reference_to "ModelRegistry::AiModel", as: :model
    reference_to "GovernancePolicy", as: :policy
    attribute :requirement, String
    attribute :reason, String
    attribute :approved_by_id, String
    attribute :approved_at, DateTime
    attribute :expires_at, Date
    attribute :scope, String
    attribute :status, String

    validation :model_id, {:presence=>true}

    validation :policy_id, {:presence=>true}

    query "ByModel" do
      where(model_id: model_id)
    end

    query "Active" do
      where(status: "active")
    end

    specification "Expired" do |e|
      e.expires_at && e.expires_at.to_s < Date.today.to_s
    end

    command "RequestExemption" do
      attribute :model_id, reference_to("AiModel")
      attribute :policy_id, reference_to("GovernancePolicy")
      attribute :requirement, String
      attribute :reason, String
    end

    command "ApproveExemption" do
      attribute :exemption_id, reference_to("Exemption")
      attribute :approved_by_id, String
      attribute :expires_at, Date
      actor "governance_board"
      actor "admin"
    end

    command "RevokeExemption" do
      attribute :exemption_id, reference_to("Exemption")
      actor "governance_board"
      actor "admin"
    end
  end

  aggregate "TrainingRecord" do
    reference_to "Identity::Stakeholder"
    reference_to "GovernancePolicy", as: :policy
    attribute :completed_at, DateTime
    attribute :expires_at, Date
    attribute :certification_id, String
    attribute :status, String

    validation :stakeholder_id, {:presence=>true}

    validation :policy_id, {:presence=>true}

    invariant "expires_at must be after completed_at" do
      !expires_at || !completed_at || expires_at.to_s >= completed_at.to_s[0, 10]
    end

    query "ByStakeholder" do
      where(stakeholder_id: stakeholder_id)
    end

    query "ByPolicy" do
      where(policy_id: policy_id)
    end

    query "Incomplete" do
      where(status: "assigned")
    end

    specification "Expired" do |t|
      t.expires_at && t.expires_at.to_s < Date.today.to_s
    end

    command "AssignTraining" do
      attribute :stakeholder_id, reference_to("Stakeholder")
      attribute :policy_id, reference_to("GovernancePolicy")
    end

    command "CompleteTraining" do
      attribute :training_record_id, reference_to("TrainingRecord")
      attribute :certification_id, String
      attribute :expires_at, Date
    end

    command "RenewTraining" do
      attribute :training_record_id, reference_to("TrainingRecord")
      attribute :certification_id, String
      attribute :expires_at, Date
    end
  end
end
