module ComplianceDomain
  class RegulatoryFramework
    class FrameworkRequirement
      attr_reader :article, :section, :description, :risk_category

      def initialize(article:, section:, description:, risk_category:)
        @article = article
        @section = section
        @description = description
        @risk_category = risk_category
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          article == other.article &&
          section == other.section &&
          description == other.description &&
          risk_category == other.risk_category
      end
      alias eql? ==

      def hash
        [self.class, article, section, description, risk_category].hash
      end

      private

      def check_invariants!; end
    end
  end
end
