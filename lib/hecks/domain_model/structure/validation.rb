# Hecks::DomainModel::Structure::Validation
#
# A validation rule for an aggregate attribute (presence, type).
#
module Hecks
  module DomainModel
    module Structure
    class Validation
      attr_reader :field, :rules

      def initialize(field:, rules:)
        @field = field.to_sym
        @rules = rules
      end

      def presence?
        rules[:presence]
      end

      def type_rule
        rules[:type]
      end
    end
    end
  end
end
