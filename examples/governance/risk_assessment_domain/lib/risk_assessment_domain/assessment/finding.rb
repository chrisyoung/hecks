module RiskAssessmentDomain
  class Assessment
    class Finding
      attr_reader :category, :severity, :description

      def initialize(category:, severity:, description:)
        @category = category
        @severity = severity
        @description = description
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          category == other.category &&
          severity == other.severity &&
          description == other.description
      end
      alias eql? ==

      def hash
        [self.class, category, severity, description].hash
      end

      private

      def check_invariants!; end
    end
  end
end
