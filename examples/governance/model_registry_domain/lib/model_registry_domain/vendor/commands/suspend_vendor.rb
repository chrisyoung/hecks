module ModelRegistryDomain
  class Vendor
    module Commands
      class SuspendVendor
        include Hecks::Command
        emits "SuspendedVendor"

        attr_reader :vendor_id

        def initialize(vendor_id: nil)
          @vendor_id = vendor_id
        end

        def call
          existing = repository.find(vendor_id)
          if existing
            unless existing.status == "approved"
              raise ModelRegistryDomain::Error, "Cannot SuspendVendor: status must be 'approved', got '#{existing.status}'"
            end
            Vendor.new(
              id: existing.id,
              name: existing.name,
              contact_email: existing.contact_email,
              risk_tier: existing.risk_tier,
              assessment_date: existing.assessment_date,
              next_review_date: existing.next_review_date,
              sla_terms: existing.sla_terms,
              status: "suspended"
            )
          else
            raise ModelRegistryDomain::Error, "Vendor not found: #{vendor_id}"
          end
        end
      end
    end
  end
end
