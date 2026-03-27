module ModelRegistryDomain
  class DataUsageAgreement
    class Restriction
      attr_reader :type, :description

      def initialize(type:, description:)
        @type = type
        @description = description
        check_invariants!
        freeze
      end

      def ==(other)
        other.is_a?(self.class) &&
          type == other.type &&
          description == other.description
      end
      alias eql? ==

      def hash
        [self.class, type, description].hash
      end

      private

      def check_invariants!; end
    end
  end
end
