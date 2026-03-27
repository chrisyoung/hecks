module ComplianceDomain
  class GovernancePolicy
    class Requirement
      attr_reader :description, :priority, :category

      def initialize(description:, priority:, category:)
        @description = description
        @priority = priority
        @category = category
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          description == other.description &&
          priority == other.priority &&
          category == other.category
      end
      alias eql? ==

      def hash
        [self.class, description, priority, category].hash
      end

      private

      def check_invariants!; end
    end
  end
end
