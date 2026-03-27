module ModelRegistryDomain
  class DataUsageAgreement
    module Events
      class RenewedAgreement
        attr_reader :aggregate_id, :agreement_id, :expiration_date, :model_id, :data_source, :purpose, :consent_type, :effective_date, :restrictions, :status, :occurred_at

        def initialize(aggregate_id: nil, agreement_id: nil, expiration_date: nil, model_id: nil, data_source: nil, purpose: nil, consent_type: nil, effective_date: nil, restrictions: nil, status: nil)
          @aggregate_id = aggregate_id
          @agreement_id = agreement_id
          @expiration_date = expiration_date
          @model_id = model_id
          @data_source = data_source
          @purpose = purpose
          @consent_type = consent_type
          @effective_date = effective_date
          @restrictions = restrictions
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
