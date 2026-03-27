module ModelRegistryDomain
  class DataUsageAgreement
    module Commands
      class RenewAgreement
        include Hecks::Command
        emits "RenewedAgreement"

        attr_reader :agreement_id, :expiration_date

        def initialize(agreement_id: nil, expiration_date: nil)
          @agreement_id = agreement_id
          @expiration_date = expiration_date
        end

        def call
          existing = repository.find(agreement_id)
          if existing
            unless ["active", "revoked"].include?(existing.status)
              raise Hecks::Error, "Cannot RenewAgreement: status must be one of active, revoked, got '#{existing.status}'"
            end
            DataUsageAgreement.new(
              id: existing.id,
              model_id: existing.model_id,
              data_source: existing.data_source,
              purpose: existing.purpose,
              consent_type: existing.consent_type,
              effective_date: existing.effective_date,
              expiration_date: expiration_date,
              restrictions: existing.restrictions,
              status: "active"
            )
          else
            raise Hecks::Error, "DataUsageAgreement not found: #{agreement_id}"
          end
        end
      end
    end
  end
end
