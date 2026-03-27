module IdentityDomain
  class Stakeholder
    module Events
      class DeactivatedStakeholder
        attr_reader :aggregate_id, :stakeholder_id, :name, :email, :role, :team, :status, :occurred_at

        def initialize(aggregate_id: nil, stakeholder_id: nil, name: nil, email: nil, role: nil, team: nil, status: nil)
          @aggregate_id = aggregate_id
          @stakeholder_id = stakeholder_id
          @name = name
          @email = email
          @role = role
          @team = team
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
