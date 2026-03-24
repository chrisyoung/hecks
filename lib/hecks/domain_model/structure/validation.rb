# Hecks::DomainModel::Structure::Validation
#
# A validation rule for an aggregate attribute. Supports presence checks
# and type constraints. Rules are stored as a hash (e.g. { presence: true, type: String }).
#
# Part of the DomainModel IR layer. Built by the DSL validation helpers and
# consumed by generators to produce attribute validation logic.
#
#   v = Validation.new(field: :name, rules: { presence: true, type: String })
#   v.presence?   # => true
#   v.type_rule   # => String
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

      def uniqueness?
        !!rules[:uniqueness]
      end
    end
    end
  end
end
