module ModelRegistryDomain
  class Vendor
    module Events
      class ApprovedVendor
        attr_reader :aggregate_id, :vendor_id, :assessment_date, :next_review_date, :name, :contact_email, :risk_tier, :sla_terms, :status, :occurred_at

        def initialize(aggregate_id: nil, vendor_id: nil, assessment_date: nil, next_review_date: nil, name: nil, contact_email: nil, risk_tier: nil, sla_terms: nil, status: nil)
          @aggregate_id = aggregate_id
          @vendor_id = vendor_id
          @assessment_date = assessment_date
          @next_review_date = next_review_date
          @name = name
          @contact_email = contact_email
          @risk_tier = risk_tier
          @sla_terms = sla_terms
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
