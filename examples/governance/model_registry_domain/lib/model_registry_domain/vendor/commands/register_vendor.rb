module ModelRegistryDomain
  class Vendor
    module Commands
      class RegisterVendor
        include Hecks::Command
        emits "RegisteredVendor"

        attr_reader :name
        attr_reader :contact_email
        attr_reader :risk_tier

        def initialize(
          name: nil,
          contact_email: nil,
          risk_tier: nil
        )
          @name = name
          @contact_email = contact_email
          @risk_tier = risk_tier
        end

        def call
          Vendor.new(
            name: name,
            contact_email: contact_email,
            risk_tier: risk_tier,
            status: "pending_review"
          )
        end
      end
    end
  end
end
