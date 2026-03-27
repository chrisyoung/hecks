module OperationsDomain
  class Monitoring
    module Specifications
      class ThresholdBreached
        def satisfied_by?(m)
          m.threshold && m.value && m.value > m.threshold
        end
      end
    end
  end
end
