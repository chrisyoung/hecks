module ModelRegistryDomain
  class AiModel
    class IntendedUse
      attr_reader :description, :domain

      def initialize(description:, domain:)
        @description = description
        @domain = domain
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          description == other.description &&
          domain == other.domain
      end
      alias eql? ==

      def hash
        [self.class, description, domain].hash
      end

      private

      def check_invariants!; end
    end
  end
end
