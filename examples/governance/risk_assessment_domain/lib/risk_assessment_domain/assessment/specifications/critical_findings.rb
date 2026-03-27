module RiskAssessmentDomain
  class Assessment
    module Specifications
      class CriticalFindings
        def satisfied_by?(assessment)
          assessment.findings.any? { |f| f.severity == "critical" }
        end
      end
    end
  end
end
