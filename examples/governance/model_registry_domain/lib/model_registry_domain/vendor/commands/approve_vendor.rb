module ModelRegistryDomain
  class Vendor
    module Commands
      class ApproveVendor
        include Hecks::Command
        emits "ApprovedVendor"

        attr_reader :vendor_id
        attr_reader :assessment_date
        attr_reader :next_review_date

        def initialize(
          vendor_id: nil,
          assessment_date: nil,
          next_review_date: nil
        )
          @vendor_id = vendor_id
          @assessment_date = assessment_date
          @next_review_date = next_review_date
        end

        def call
          existing = repository.find(vendor_id)
          if existing
            unless existing.status == "pending_review"
              raise ModelRegistryDomain::Error, "Cannot ApproveVendor: status must be 'pending_review', got '#{existing.status}'"
            end
            Vendor.new(
              id: existing.id,
              name: existing.name,
              contact_email: existing.contact_email,
              risk_tier: existing.risk_tier,
              assessment_date: assessment_date,
              next_review_date: next_review_date,
              sla_terms: existing.sla_terms,
              status: "approved"
            )
          else
            raise ModelRegistryDomain::Error, "Vendor not found: #{vendor_id}"
          end
        end
      end
    end
  end
end
