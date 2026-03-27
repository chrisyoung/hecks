module ComplianceDomain
  class RegulatoryFramework
    module Events
      class RegisteredFramework
        attr_reader :aggregate_id, :name, :jurisdiction, :version, :authority, :effective_date, :requirements, :status, :occurred_at

        def initialize(aggregate_id: nil, name: nil, jurisdiction: nil, version: nil, authority: nil, effective_date: nil, requirements: nil, status: nil)
          @aggregate_id = aggregate_id
          @name = name
          @jurisdiction = jurisdiction
          @version = version
          @authority = authority
          @effective_date = effective_date
          @requirements = requirements
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
