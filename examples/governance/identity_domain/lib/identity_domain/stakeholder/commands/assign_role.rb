module IdentityDomain
  class Stakeholder
    module Commands
      class AssignRole
        include Hecks::Command
        emits "AssignedRole"

        attr_reader :stakeholder_id, :role

        def initialize(stakeholder_id: nil, role: nil)
          @stakeholder_id = stakeholder_id
          @role = role
        end

        def call
          existing = repository.find(stakeholder_id)
          if existing
            Stakeholder.new(
              id: existing.id,
              name: existing.name,
              email: existing.email,
              team: existing.team,
              status: existing.status,
              role: role
            )
          else
            raise Hecks::Error, "Stakeholder not found: #{stakeholder_id}"
          end
        end
      end
    end
  end
end
