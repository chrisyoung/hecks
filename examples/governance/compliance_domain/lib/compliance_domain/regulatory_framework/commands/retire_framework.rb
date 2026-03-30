module ComplianceDomain
  class RegulatoryFramework
    module Commands
      class RetireFramework
        include Hecks::Command
        emits "RetiredFramework"

        attr_reader :framework_id

        def initialize(framework_id: nil)
          @framework_id = framework_id
        end

        def call
          existing = repository.find(framework_id)
          if existing
            unless existing.status == "active"
              raise ComplianceDomain::Error, "Cannot RetireFramework: status must be 'active', got '#{existing.status}'"
            end
            RegulatoryFramework.new(
              id: existing.id,
              name: existing.name,
              jurisdiction: existing.jurisdiction,
              version: existing.version,
              effective_date: existing.effective_date,
              authority: existing.authority,
              requirements: existing.requirements,
              status: "retired"
            )
          else
            raise ComplianceDomain::Error, "RegulatoryFramework not found: #{framework_id}"
          end
        end
      end
    end
  end
end
