require 'hecks/mixins/model'

module RiskAssessmentDomain
  class Assessment
    class Finding
      include Hecks::Model

      attribute :category
      attribute :severity
      attribute :description
      attribute :status

      private

      def check_invariants!
        raise RiskAssessmentDomain::InvariantError, "severity must be valid" unless instance_eval(&proc {  })
      end
    end
  end
end
