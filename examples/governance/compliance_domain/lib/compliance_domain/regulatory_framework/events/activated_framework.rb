module ComplianceDomain
  class RegulatoryFramework
    module Events
      class ActivatedFramework
        attr_reader :aggregate_id, :framework_id, :effective_date, :name, :jurisdiction, :version, :authority, :requirements, :status, :occurred_at

        def initialize(aggregate_id: nil, framework_id: nil, effective_date: nil, name: nil, jurisdiction: nil, version: nil, authority: nil, requirements: nil, status: nil)
          @aggregate_id = aggregate_id
          @framework_id = framework_id
          @effective_date = effective_date
          @name = name
          @jurisdiction = jurisdiction
          @version = version
          @authority = authority
          @requirements = requirements
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
