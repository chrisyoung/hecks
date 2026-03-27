require "date"

Hecks.domain "Compliance" do
  aggregate "GovernancePolicy" do
    attribute :name, String
    attribute :description, String
    attribute :category, String, enum: %w[regulatory internal ethical operational]
    attribute :framework_id, String
    attribute :effective_date, Date
    attribute :review_date, Date
    attribute :requirements, list_of("Requirement")

    attribute :status, String
    lifecycle :status, default: "draft" do
      transition "CreatePolicy"   => "draft"
      transition "ActivatePolicy" => "active",    from: "draft"
      transition "SuspendPolicy"  => "suspended", from: "active"
      transition "RetirePolicy"   => "retired",   from: ["active", "suspended"]
    end

    value_object "Requirement" do
      attribute :description, String
      attribute :priority, String, enum: %w[low medium high critical]
      attribute :category, String
    end

    validation :name, presence: true
    validation :category, presence: true

    command "CreatePolicy" do
      attribute :name, String
      attribute :description, String
      attribute :category, String
      attribute :framework_id, String
      actor "governance_board"
      actor "admin"
    end

    command "ActivatePolicy" do
      attribute :policy_id, String
      attribute :effective_date, Date
      actor "governance_board"
      actor "admin"
    end

    command "SuspendPolicy" do
      attribute :policy_id, String
      actor "governance_board"
      actor "admin"
    end

    command "RetirePolicy" do
      attribute :policy_id, String
      actor "governance_board"
      actor "admin"
    end

    command "UpdateReviewDate" do
      attribute :policy_id, String
      attribute :review_date, Date
      actor "governance_board"
      actor "admin"
    end

    query "ByCategory" do |category|
      where(category: category)
    end

    query "ByFramework" do |framework_id|
      where(framework_id: framework_id)
    end

    query "Active" do
      where(status: "active")
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
    lifecycle :status, default: "draft" do
      transition "RegisterFramework" => "draft"
      transition "ActivateFramework" => "active",  from: "draft"
      transition "RetireFramework"   => "retired", from: "active"
    end

    value_object "FrameworkRequirement" do
      attribute :article, String
      attribute :section, String
      attribute :description, String
      attribute :risk_category, String
    end

    validation :name, presence: true
    validation :jurisdiction, presence: true

    command "RegisterFramework" do
      attribute :name, String
      attribute :jurisdiction, String
      attribute :version, String
      attribute :authority, String
    end

    command "ActivateFramework" do
      attribute :framework_id, String
      attribute :effective_date, Date
    end

    command "RetireFramework" do
      attribute :framework_id, String
    end

    query "ByJurisdiction" do |jurisdiction|
      where(jurisdiction: jurisdiction)
    end

    query "Active" do
      where(status: "active")
    end
  end

  aggregate "ComplianceReview" do
    attachable
    attribute :model_id, String
    attribute :policy_id, String
    attribute :reviewer_id, String
    attribute :outcome, String, enum: %w[approved rejected]
    attribute :notes, String
    attribute :completed_at, DateTime
    attribute :conditions, list_of("ReviewCondition")

    attribute :status, String
    lifecycle :status, default: "open" do
      transition "OpenReview"      => "open"
      transition "ApproveReview"   => "approved",          from: ["open", "changes_requested"]
      transition "RejectReview"    => "rejected",          from: ["open", "changes_requested"]
      transition "RequestChanges"  => "changes_requested", from: "open"
    end

    value_object "ReviewCondition" do
      attribute :requirement, String
      attribute :met, String, enum: %w[yes no partial]
      attribute :evidence, String
    end

    validation :model_id, presence: true
    validation :reviewer_id, presence: true

    command "OpenReview" do
      attribute :model_id, String
      attribute :policy_id, String
      attribute :reviewer_id, String
      actor "reviewer"
      actor "admin"
    end

    command "ApproveReview" do
      attribute :review_id, String
      attribute :notes, String
      sets outcome: "approved", completed_at: :now
      actor "reviewer"
      actor "admin"
    end

    command "RejectReview" do
      attribute :review_id, String
      attribute :notes, String
      sets outcome: "rejected", completed_at: :now
      actor "reviewer"
      actor "admin"
    end

    command "RequestChanges" do
      attribute :review_id, String
      attribute :notes, String
      actor "reviewer"
      actor "admin"
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "Pending" do
      where(status: "open")
    end

    query "ByReviewer" do |reviewer_id|
      where(reviewer_id: reviewer_id)
    end
  end

  aggregate "Exemption" do
    attribute :model_id, String
    attribute :policy_id, String
    attribute :requirement, String
    attribute :reason, String
    attribute :approved_by_id, String
    attribute :approved_at, DateTime
    attribute :expires_at, Date
    attribute :scope, String

    attribute :status, String
    lifecycle :status, default: "requested" do
      transition "RequestExemption" => "requested"
      transition "ApproveExemption" => "active",  from: "requested"
      transition "RevokeExemption"  => "revoked", from: "active"
    end

    validation :model_id, presence: true
    validation :policy_id, presence: true

    command "RequestExemption" do
      attribute :model_id, String
      attribute :policy_id, String
      attribute :requirement, String
      attribute :reason, String
    end

    command "ApproveExemption" do
      attribute :exemption_id, String
      attribute :approved_by_id, String
      attribute :expires_at, Date
      sets approved_at: :now
      actor "governance_board"
      actor "admin"
    end

    command "RevokeExemption" do
      attribute :exemption_id, String
      actor "governance_board"
      actor "admin"
    end

    specification "Expired" do |e|
      e.expires_at && e.expires_at.to_s < Date.today.to_s
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "Active" do
      where(status: "active")
    end
  end

  aggregate "TrainingRecord" do
    attribute :stakeholder_id, String
    attribute :policy_id, String
    attribute :completed_at, DateTime
    attribute :expires_at, Date
    attribute :certification_id, String

    attribute :status, String
    lifecycle :status, default: "assigned" do
      transition "AssignTraining"   => "assigned"
      transition "CompleteTraining" => "completed", from: "assigned"
      transition "RenewTraining"    => "completed", from: "completed"
    end

    validation :stakeholder_id, presence: true
    validation :policy_id, presence: true

    invariant "expires_at must be after completed_at" do
      !expires_at || !completed_at || expires_at.to_s >= completed_at.to_s[0, 10]
    end

    command "AssignTraining" do
      attribute :stakeholder_id, String
      attribute :policy_id, String
    end

    command "CompleteTraining" do
      attribute :training_record_id, String
      attribute :certification_id, String
      attribute :expires_at, Date
      sets completed_at: :now
    end

    command "RenewTraining" do
      attribute :training_record_id, String
      attribute :certification_id, String
      attribute :expires_at, Date
      sets completed_at: :now
    end

    specification "Expired" do |t|
      t.expires_at && t.expires_at.to_s < Date.today.to_s
    end

    query "ByStakeholder" do |stakeholder_id|
      where(stakeholder_id: stakeholder_id)
    end

    query "ByPolicy" do |policy_id|
      where(policy_id: policy_id)
    end

    query "Incomplete" do
      where(status: "assigned")
    end
  end
end
