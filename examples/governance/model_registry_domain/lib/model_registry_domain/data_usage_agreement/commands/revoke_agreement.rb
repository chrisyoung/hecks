module ModelRegistryDomain
  class DataUsageAgreement
    module Commands
      class RevokeAgreement
        include Hecks::Command
        emits "RevokedAgreement"

        attr_reader :agreement_id

        def initialize(agreement_id: nil)
          @agreement_id = agreement_id
        end

        def call
          existing = repository.find(agreement_id)
          if existing
            unless existing.status == "active"
              raise Hecks::Error, "Cannot RevokeAgreement: status must be 'active', got '#{existing.status}'"
            end
            DataUsageAgreement.new(
              id: existing.id,
              model_id: existing.model_id,
              data_source: existing.data_source,
              purpose: existing.purpose,
              consent_type: existing.consent_type,
              effective_date: existing.effective_date,
              expiration_date: existing.expiration_date,
              restrictions: existing.restrictions,
              status: "revoked"
            )
          else
            raise Hecks::Error, "DataUsageAgreement not found: #{agreement_id}"
          end
        end
      end
    end
  end
end
