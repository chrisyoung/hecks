module ComplianceDomain
  class Exemption
    module Commands
      class ApproveExemption
        include Hecks::Command
        emits "ApprovedExemption"

        attr_reader :exemption_id
        attr_reader :approved_by_id
        attr_reader :expires_at

        def initialize(
          exemption_id: nil,
          approved_by_id: nil,
          expires_at: nil
        )
          @exemption_id = exemption_id
          @approved_by_id = approved_by_id
          @expires_at = expires_at
        end

        def call
          existing = repository.find(exemption_id)
          if existing
            unless existing.status == "requested"
              raise Hecks::Error, "Cannot ApproveExemption: status must be 'requested', got '#{existing.status}'"
            end
            Exemption.new(
              id: existing.id,
              model_id: existing.model_id,
              policy_id: existing.policy_id,
              requirement: existing.requirement,
              reason: existing.reason,
              approved_by_id: approved_by_id,
              expires_at: expires_at,
              scope: existing.scope,
              approved_at: Time.now.to_s,
              status: "active"
            )
          else
            raise Hecks::Error, "Exemption not found: #{exemption_id}"
          end
        end
      end
    end
  end
end
