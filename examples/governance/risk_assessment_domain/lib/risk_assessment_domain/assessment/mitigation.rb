module RiskAssessmentDomain
  class Assessment
    class Mitigation
      attr_reader :finding_category, :action, :status

      def initialize(finding_category:, action:, status:)
        @finding_category = finding_category
        @action = action
        @status = status
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          finding_category == other.finding_category &&
          action == other.action &&
          status == other.status
      end
      alias eql? ==

      def hash
        [self.class, finding_category, action, status].hash
      end

      private

      def check_invariants!; end
    end
  end
end
