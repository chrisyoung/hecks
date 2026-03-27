require 'hecks/model'

module ComplianceDomain
  class RegulatoryFramework
    autoload :FrameworkRequirement, "compliance_domain/regulatory_framework/framework_requirement"
    autoload :Lifecycle, "compliance_domain/regulatory_framework/lifecycle"

    include Hecks::Model

    attribute :name
    attribute :jurisdiction
    attribute :version
    attribute :effective_date
    attribute :authority
    attribute :requirements, default: [], freeze: true
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def draft?; status == "draft"; end
    def active?; status == "active"; end
    def retired?; status == "retired"; end

    private

    def validate!
      raise ValidationError, "name can't be blank" if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      raise ValidationError, "jurisdiction can't be blank" if jurisdiction.nil? || (jurisdiction.respond_to?(:empty?) && jurisdiction.empty?)
    end
  end
end
