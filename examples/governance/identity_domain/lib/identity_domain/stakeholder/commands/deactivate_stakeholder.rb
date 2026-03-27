module IdentityDomain
  class Stakeholder
    module Commands
      class DeactivateStakeholder
        include Hecks::Command
        emits "DeactivatedStakeholder"

        attr_reader :stakeholder_id

        def initialize(stakeholder_id: nil)
          @stakeholder_id = stakeholder_id
        end

        def call
          existing = repository.find(stakeholder_id)
          if existing
            unless existing.status == "active"
              raise Hecks::Error, "Cannot DeactivateStakeholder: status must be 'active', got '#{existing.status}'"
            end
            Stakeholder.new(
              id: existing.id,
              name: existing.name,
              email: existing.email,
              role: existing.role,
              team: existing.team,
              status: "deactivated"
            )
          else
            raise Hecks::Error, "Stakeholder not found: #{stakeholder_id}"
          end
        end
      end
    end
  end
end
