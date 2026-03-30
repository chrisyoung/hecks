module ComplianceDomain
  class Exemption
    module Commands
      class RevokeExemption
        include Hecks::Command
        emits "RevokedExemption"

        attr_reader :exemption_id

        def initialize(exemption_id: nil)
          @exemption_id = exemption_id
        end

        def call
          existing = repository.find(exemption_id)
          if existing
            unless existing.status == "active"
              raise ComplianceDomain::Error, "Cannot RevokeExemption: status must be 'active', got '#{existing.status}'"
            end
            Exemption.new(
              id: existing.id,
              model_id: existing.model_id,
              policy_id: existing.policy_id,
              requirement: existing.requirement,
              reason: existing.reason,
              approved_by_id: existing.approved_by_id,
              approved_at: existing.approved_at,
              expires_at: existing.expires_at,
              scope: existing.scope,
              status: "revoked"
            )
          else
            raise ComplianceDomain::Error, "Exemption not found: #{exemption_id}"
          end
        end
      end
    end
  end
end
