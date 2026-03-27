module ComplianceDomain
  class ComplianceReview
    class ReviewCondition
      attr_reader :requirement, :met, :evidence

      def initialize(requirement:, met:, evidence:)
        @requirement = requirement
        @met = met
        @evidence = evidence
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          requirement == other.requirement &&
          met == other.met &&
          evidence == other.evidence
      end
      alias eql? ==

      def hash
        [self.class, requirement, met, evidence].hash
      end

      private

      def check_invariants!; end
    end
  end
end
