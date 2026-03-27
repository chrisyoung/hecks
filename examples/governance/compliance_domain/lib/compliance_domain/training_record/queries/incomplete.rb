module ComplianceDomain
  class TrainingRecord
    module Queries
      class Incomplete
        def call
          where(status: "assigned")
        end
      end
    end
  end
end
