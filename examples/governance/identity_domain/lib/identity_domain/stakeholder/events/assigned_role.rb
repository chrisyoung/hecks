module IdentityDomain
  class Stakeholder
    module Events
      class AssignedRole
        attr_reader :aggregate_id, :stakeholder_id, :role, :name, :email, :team, :status, :occurred_at

        def initialize(aggregate_id: nil, stakeholder_id: nil, role: nil, name: nil, email: nil, team: nil, status: nil)
          @aggregate_id = aggregate_id
          @stakeholder_id = stakeholder_id
          @role = role
          @name = name
          @email = email
          @team = team
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
