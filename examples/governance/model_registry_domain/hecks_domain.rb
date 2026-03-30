Hecks.domain "ModelRegistry" do
  uses_kernel "Identity"

  driving_port :http, description: "REST API"
  driving_port :mcp, description: "AI tool interface"
  driving_port :events, description: "Cross-domain event bus"

  driven_port :persistence, [:find, :save, :delete, :all]
  driven_port :notifications, [:send_email, :send_webhook], description: "Model status alerts"

  actor "governance_board", description: "Model approval authority"
  actor "data_steward", description: "Data usage governance"
  actor "admin", description: "System administrator"

  published_event "ModelRegistered", version: 1 do
    attribute :model_id, String
    attribute :name, String
    attribute :version, String
  end

  published_event "ModelSuspended", version: 1 do
    attribute :model_id, String
    attribute :reason, String
  end

  service "ModelOnboardingService" do
    coordinates "AiModel", "Vendor"
    attribute :name, String
    attribute :vendor_name, String
  end

  aggregate "AiModel" do
    attribute :name, String
    attribute :version, String
    reference_to "Vendor"
    attribute :description, String
    attribute :risk_level, String
    attribute :registered_at, DateTime
    reference_to "AiModel", as: :parent_model
    attribute :derivation_type, String
    attribute :capabilities, list_of("Capability")
    attribute :intended_uses, list_of("IntendedUse")
    attribute :status, String

    value_object "Capability" do
      attribute :name, String
      attribute :category, String
    end

    value_object "IntendedUse" do
      attribute :description, String
      attribute :domain, String
    end

    validation :name, {:presence=>true}

    validation :version, {:presence=>true}

    query "ByProvider" do
      where(provider_id: provider_id)
    end

    query "ByRiskLevel" do
      where(risk_level: level)
    end

    query "ByStatus" do
      where(status: status)
    end

    query "ByParent" do
      where(parent_model_id: parent_id)
    end

    specification "HighRisk" do |model|
      model.risk_level == "high" || model.risk_level == "critical"
    end

    command "RegisterModel" do
      attribute :name, String
      attribute :version, String
      attribute :provider_id, reference_to("Vendor")
      attribute :description, String
    end

    command "DeriveModel" do
      attribute :name, String
      attribute :version, String
      attribute :parent_model_id, reference_to("AiModel")
      attribute :derivation_type, String
      attribute :description, String
    end

    command "ClassifyRisk" do
      attribute :model_id, reference_to("AiModel")
      attribute :risk_level, String
    end

    command "ApproveModel" do
      attribute :model_id, reference_to("AiModel")
      actor "governance_board"
      actor "admin"
    end

    command "SuspendModel" do
      attribute :model_id, reference_to("AiModel")
      actor "governance_board"
      actor "admin"
    end

    command "RetireModel" do
      attribute :model_id, reference_to("AiModel")
      actor "governance_board"
      actor "admin"
    end

    policy "ClassifyAfterAssessment" do
      on "SubmittedAssessment"
      trigger "ClassifyRisk"
    end

    policy "SuspendOnReject" do
      on "RejectedReview"
      trigger "SuspendModel"
    end

    policy "SuspendOnCriticalIncident" do
      on "ReportedIncident"
      trigger "SuspendModel"
      condition { |event|  }
    end
  end

  aggregate "Vendor" do
    attribute :name, String
    attribute :contact_email, String
    attribute :risk_tier, String
    attribute :assessment_date, Date
    attribute :next_review_date, Date
    attribute :sla_terms, String
    attribute :status, String

    validation :name, {:presence=>true}

    query "ByRiskTier" do
      where(risk_tier: tier)
    end

    query "Active" do
      where(status: "approved")
    end

    command "RegisterVendor" do
      attribute :name, String
      attribute :contact_email, String
      attribute :risk_tier, String
    end

    command "ApproveVendor" do
      attribute reference_to("Vendor")
      attribute :assessment_date, Date
      attribute :next_review_date, Date
      actor "governance_board"
      actor "admin"
    end

    command "SuspendVendor" do
      attribute reference_to("Vendor")
      actor "governance_board"
      actor "admin"
    end
  end

  aggregate "DataUsageAgreement" do
    reference_to "AiModel", as: :model
    attribute :data_source, String
    attribute :purpose, String
    attribute :consent_type, String
    attribute :effective_date, Date
    attribute :expiration_date, Date
    attribute :restrictions, list_of("Restriction")
    attribute :status, String

    value_object "Restriction" do
      attribute :type, String
      attribute :description, String
    end

    validation :data_source, {:presence=>true}

    validation :purpose, {:presence=>true}

    invariant "expiration must be after effective date" do
      !expiration_date || !effective_date || expiration_date.to_s >= effective_date.to_s
    end

    query "ByModel" do
      where(model_id: model_id)
    end

    query "Active" do
      where(status: "active")
    end

    specification "Expired" do |agreement|
      agreement.expiration_date && agreement.expiration_date.to_s < Date.today.to_s
    end

    command "CreateAgreement" do
      attribute :model_id, reference_to("AiModel")
      attribute :data_source, String
      attribute :purpose, String
      attribute :consent_type, String
      actor "data_steward"
      actor "admin"
    end

    command "ActivateAgreement" do
      attribute reference_to("DataUsageAgreement")
      attribute :effective_date, Date
      attribute :expiration_date, Date
      actor "data_steward"
      actor "admin"
    end

    command "RevokeAgreement" do
      attribute reference_to("DataUsageAgreement")
      actor "data_steward"
      actor "admin"
    end

    command "RenewAgreement" do
      attribute reference_to("DataUsageAgreement")
      attribute :expiration_date, Date
      actor "data_steward"
      actor "admin"
    end
  end
end
