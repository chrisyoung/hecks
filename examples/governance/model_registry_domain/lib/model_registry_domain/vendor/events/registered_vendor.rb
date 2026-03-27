module ModelRegistryDomain
  class Vendor
    module Events
      class RegisteredVendor
        attr_reader :aggregate_id, :name, :contact_email, :risk_tier, :assessment_date, :next_review_date, :sla_terms, :status, :occurred_at

        def initialize(aggregate_id: nil, name: nil, contact_email: nil, risk_tier: nil, assessment_date: nil, next_review_date: nil, sla_terms: nil, status: nil)
          @aggregate_id = aggregate_id
          @name = name
          @contact_email = contact_email
          @risk_tier = risk_tier
          @assessment_date = assessment_date
          @next_review_date = next_review_date
          @sla_terms = sla_terms
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
