module ModelRegistryDomain
  class AiModel
    class Capability
      attr_reader :name, :category

      def initialize(name:, category:)
        @name = name
        @category = category
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          name == other.name &&
          category == other.category
      end
      alias eql? ==

      def hash
        [self.class, name, category].hash
      end

      private

      def check_invariants!; end
    end
  end
end
