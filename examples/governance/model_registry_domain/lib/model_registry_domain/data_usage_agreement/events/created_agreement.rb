module ModelRegistryDomain
  class DataUsageAgreement
    module Events
      class CreatedAgreement
        attr_reader :aggregate_id, :model_id, :data_source, :purpose, :consent_type, :effective_date, :expiration_date, :restrictions, :status, :occurred_at

        def initialize(aggregate_id: nil, model_id: nil, data_source: nil, purpose: nil, consent_type: nil, effective_date: nil, expiration_date: nil, restrictions: nil, status: nil)
          @aggregate_id = aggregate_id
          @model_id = model_id
          @data_source = data_source
          @purpose = purpose
          @consent_type = consent_type
          @effective_date = effective_date
          @expiration_date = expiration_date
          @restrictions = restrictions
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
