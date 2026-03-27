module ComplianceDomain
  class RegulatoryFramework
    module Commands
      class ActivateFramework
        include Hecks::Command
        emits "ActivatedFramework"

        attr_reader :framework_id, :effective_date

        def initialize(framework_id: nil, effective_date: nil)
          @framework_id = framework_id
          @effective_date = effective_date
        end

        def call
          existing = repository.find(framework_id)
          if existing
            unless existing.status == "draft"
              raise Hecks::Error, "Cannot ActivateFramework: status must be 'draft', got '#{existing.status}'"
            end
            RegulatoryFramework.new(
              id: existing.id,
              name: existing.name,
              jurisdiction: existing.jurisdiction,
              version: existing.version,
              effective_date: effective_date,
              authority: existing.authority,
              requirements: existing.requirements,
              status: "active"
            )
          else
            raise Hecks::Error, "RegulatoryFramework not found: #{framework_id}"
          end
        end
      end
    end
  end
end
