module ComplianceDomain
  class Exemption
    module Events
      class RevokedExemption
        attr_reader :aggregate_id, :exemption_id, :model_id, :policy_id, :requirement, :reason, :approved_by_id, :approved_at, :expires_at, :scope, :status, :occurred_at

        def initialize(aggregate_id: nil, exemption_id: nil, model_id: nil, policy_id: nil, requirement: nil, reason: nil, approved_by_id: nil, approved_at: nil, expires_at: nil, scope: nil, status: nil)
          @aggregate_id = aggregate_id
          @exemption_id = exemption_id
          @model_id = model_id
          @policy_id = policy_id
          @requirement = requirement
          @reason = reason
          @approved_by_id = approved_by_id
          @approved_at = approved_at
          @expires_at = expires_at
          @scope = scope
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
