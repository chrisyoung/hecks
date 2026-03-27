module ComplianceDomain
  class RegulatoryFramework
    module Events
      class RetiredFramework
        attr_reader :aggregate_id, :framework_id, :name, :jurisdiction, :version, :effective_date, :authority, :requirements, :status, :occurred_at

        def initialize(aggregate_id: nil, framework_id: nil, name: nil, jurisdiction: nil, version: nil, effective_date: nil, authority: nil, requirements: nil, status: nil)
          @aggregate_id = aggregate_id
          @framework_id = framework_id
          @name = name
          @jurisdiction = jurisdiction
          @version = version
          @effective_date = effective_date
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
