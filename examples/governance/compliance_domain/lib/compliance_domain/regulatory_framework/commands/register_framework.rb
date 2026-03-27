module ComplianceDomain
  class RegulatoryFramework
    module Commands
      class RegisterFramework
        include Hecks::Command
        emits "RegisteredFramework"

        attr_reader :name
        attr_reader :jurisdiction
        attr_reader :version
        attr_reader :authority

        def initialize(
          name: nil,
          jurisdiction: nil,
          version: nil,
          authority: nil
        )
          @name = name
          @jurisdiction = jurisdiction
          @version = version
          @authority = authority
        end

        def call
          RegulatoryFramework.new(
            name: name,
            jurisdiction: jurisdiction,
            version: version,
            authority: authority,
            status: "draft"
          )
        end
      end
    end
  end
end
