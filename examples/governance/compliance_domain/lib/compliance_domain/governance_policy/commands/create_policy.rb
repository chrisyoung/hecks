module ComplianceDomain
  class GovernancePolicy
    module Commands
      class CreatePolicy
        include Hecks::Command
        emits "CreatedPolicy"

        attr_reader :name
        attr_reader :description
        attr_reader :category
        attr_reader :framework_id

        def initialize(
          name: nil,
          description: nil,
          category: nil,
          framework_id: nil
        )
          @name = name
          @description = description
          @category = category
          @framework_id = framework_id
        end

        def call
          GovernancePolicy.new(
            name: name,
            description: description,
            category: category,
            framework_id: framework_id,
            status: "draft"
          )
        end
      end
    end
  end
end
