require 'hecks/model'

module ComplianceDomain
  class GovernancePolicy
    autoload :Requirement, "compliance_domain/governance_policy/requirement"
    autoload :Lifecycle, "compliance_domain/governance_policy/lifecycle"

    include Hecks::Model

    attribute :name
    attribute :description
    attribute :category
    attribute :framework_id
    attribute :effective_date
    attribute :review_date
    attribute :requirements, default: [], freeze: true
    attribute :status

    # State predicates — see lifecycle.rb for full state machine
    def draft?; status == "draft"; end
    def active?; status == "active"; end
    def suspended?; status == "suspended"; end
    def retired?; status == "retired"; end

    VALID_CATEGORY = ["regulatory", "internal", "ethical", "operational"].freeze unless defined?(VALID_CATEGORY)

    private

    def validate!
      raise ValidationError, "name can't be blank" if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      raise ValidationError, "category can't be blank" if category.nil? || (category.respond_to?(:empty?) && category.empty?)
      if category && !VALID_CATEGORY.include?(category)
        raise ValidationError, "category must be one of: #{VALID_CATEGORY.join(', ')}, got: #{category}"
      end
    end
  end
end
