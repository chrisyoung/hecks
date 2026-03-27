require "date"

Hecks.domain "ModelRegistry" do
  aggregate "AiModel" do
    versioned
    attribute :name, String
    attribute :version, String
    attribute :provider_id, String
    attribute :description, String
    attribute :risk_level, String, enum: %w[low medium high critical]
    attribute :registered_at, DateTime
    attribute :parent_model_id, String
    attribute :derivation_type, String, enum: %w[fine-tuned distilled retrained quantized]
    attribute :capabilities, list_of("Capability")
    attribute :intended_uses, list_of("IntendedUse")

    attribute :status, String
    lifecycle :status, default: "draft" do
      transition "RegisterModel"  => "draft"
      transition "DeriveModel"    => "draft"
      transition "ClassifyRisk"   => "classified", from: "draft"
      transition "ApproveModel"   => "approved",   from: "classified"
      transition "SuspendModel"   => "suspended",  from: ["approved", "classified", "draft"]
      transition "RetireModel"    => "retired",    from: ["approved", "suspended"]
    end

    value_object "Capability" do
      attribute :name, String
      attribute :category, String
    end

    value_object "IntendedUse" do
      attribute :description, String
      attribute :domain, String
    end

    validation :name, presence: true
    validation :version, presence: true

    command "RegisterModel" do
      attribute :name, String
      attribute :version, String
      attribute :provider_id, String
      attribute :description, String
      sets registered_at: :now
    end

    command "DeriveModel" do
      attribute :name, String
      attribute :version, String
      attribute :parent_model_id, String
      attribute :derivation_type, String
      attribute :description, String
      sets registered_at: :now
    end

    command "ClassifyRisk" do
      attribute :model_id, String
      attribute :risk_level, String
      sets risk_level: :risk_level
    end

    command "ApproveModel" do
      attribute :model_id, String
      actor "governance_board"
      actor "admin"
    end

    command "SuspendModel" do
      attribute :model_id, String
      actor "governance_board"
      actor "admin"
    end

    command "RetireModel" do
      attribute :model_id, String
      actor "governance_board"
      actor "admin"
    end

    specification "HighRisk" do |model|
      model.risk_level == "high" || model.risk_level == "critical"
    end

    query "ByProvider" do |provider_id|
      where(provider_id: provider_id)
    end

    query "ByRiskLevel" do |level|
      where(risk_level: level)
    end

    query "ByStatus" do |status|
      where(status: status)
    end

    query "ByParent" do |parent_id|
      where(parent_model_id: parent_id)
    end

    # React to events from other domains
    policy "ClassifyAfterAssessment" do
      on "SubmittedAssessment"
      trigger "ClassifyRisk"
      map model_id: :model_id, risk_level: :risk_level
    end

    policy "SuspendOnReject" do
      on "RejectedReview"
      trigger "SuspendModel"
      map model_id: :model_id
    end

    policy "SuspendOnCriticalIncident" do
      on "ReportedIncident"
      trigger "SuspendModel"
      map model_id: :model_id
      condition { |event| event.severity == "critical" }
    end
  end

  aggregate "Vendor" do
    attribute :name, String
    attribute :contact_email, String, pii: true
    attribute :risk_tier, String, enum: %w[low medium high]
    attribute :assessment_date, Date
    attribute :next_review_date, Date
    attribute :sla_terms, String

    attribute :status, String
    lifecycle :status, default: "pending_review" do
      transition "RegisterVendor" => "pending_review"
      transition "ApproveVendor"  => "approved",  from: "pending_review"
      transition "SuspendVendor"  => "suspended", from: "approved"
    end

    validation :name, presence: true

    command "RegisterVendor" do
      attribute :name, String
      attribute :contact_email, String
      attribute :risk_tier, String
    end

    command "ApproveVendor" do
      attribute :vendor_id, String
      attribute :assessment_date, Date
      attribute :next_review_date, Date
      actor "governance_board"
      actor "admin"
    end

    command "SuspendVendor" do
      attribute :vendor_id, String
      actor "governance_board"
      actor "admin"
    end

    query "ByRiskTier" do |tier|
      where(risk_tier: tier)
    end

    query "Active" do
      where(status: "approved")
    end
  end

  aggregate "DataUsageAgreement" do
    attribute :model_id, String
    attribute :data_source, String
    attribute :purpose, String
    attribute :consent_type, String, enum: %w[public_domain CC-BY-SA licensed consent opt-out]
    attribute :effective_date, Date
    attribute :expiration_date, Date
    attribute :restrictions, list_of("Restriction")

    attribute :status, String
    lifecycle :status, default: "draft" do
      transition "CreateAgreement"   => "draft"
      transition "ActivateAgreement" => "active",  from: "draft"
      transition "RevokeAgreement"   => "revoked", from: "active"
      transition "RenewAgreement"    => "active",  from: ["active", "revoked"]
    end

    value_object "Restriction" do
      attribute :type, String
      attribute :description, String
    end

    validation :data_source, presence: true
    validation :purpose, presence: true

    invariant "expiration must be after effective date" do
      !expiration_date || !effective_date || expiration_date.to_s >= effective_date.to_s
    end

    command "CreateAgreement" do
      attribute :model_id, String
      attribute :data_source, String
      attribute :purpose, String
      attribute :consent_type, String
      actor "data_steward"
      actor "admin"
    end

    command "ActivateAgreement" do
      attribute :agreement_id, String
      attribute :effective_date, Date
      attribute :expiration_date, Date
      actor "data_steward"
      actor "admin"
    end

    command "RevokeAgreement" do
      attribute :agreement_id, String
      actor "data_steward"
      actor "admin"
    end

    command "RenewAgreement" do
      attribute :agreement_id, String
      attribute :expiration_date, Date
      actor "data_steward"
      actor "admin"
    end

    specification "Expired" do |agreement|
      agreement.expiration_date && agreement.expiration_date.to_s < Date.today.to_s
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "Active" do
      where(status: "active")
    end
  end

  workflow "ModelApproval" do
    step "SubmitAssessment"
    branch do
      when_spec("HighRisk") { step "OpenReview" }
      otherwise { step "ApproveModel" }
    end
  end

  view "ModelDashboard" do
    project("RegisteredModel") do |event, state|
      state.merge(total_models: (state[:total_models] || 0) + 1)
    end

    project("ClassifiedRisk") do |event, state|
      risk = event.respond_to?(:risk_level) ? event.risk_level : "unknown"
      by_risk = state[:models_by_risk] || {}
      state.merge(models_by_risk: by_risk.merge(risk => (by_risk[risk] || 0) + 1))
    end

    project("SuspendedModel") do |event, state|
      state.merge(suspended_count: (state[:suspended_count] || 0) + 1)
    end
  end
end
