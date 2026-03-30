module ModelRegistryDomain
  class DataUsageAgreement
    module Commands
      class ActivateAgreement
        include Hecks::Command
        emits "ActivatedAgreement"

        attr_reader :agreement_id
        attr_reader :effective_date
        attr_reader :expiration_date

        def initialize(
          agreement_id: nil,
          effective_date: nil,
          expiration_date: nil
        )
          @agreement_id = agreement_id
          @effective_date = effective_date
          @expiration_date = expiration_date
        end

        def call
          existing = repository.find(agreement_id)
          if existing
            unless existing.status == "draft"
              raise ModelRegistryDomain::Error, "Cannot ActivateAgreement: status must be 'draft', got '#{existing.status}'"
            end
            DataUsageAgreement.new(
              id: existing.id,
              model_id: existing.model_id,
              data_source: existing.data_source,
              purpose: existing.purpose,
              consent_type: existing.consent_type,
              effective_date: effective_date,
              expiration_date: expiration_date,
              restrictions: existing.restrictions,
              status: "active"
            )
          else
            raise ModelRegistryDomain::Error, "DataUsageAgreement not found: #{agreement_id}"
          end
        end
      end
    end
  end
end
