# Hecks::CustomConcerns::Rule
#
# A named validation rule within a custom concern. Holds a human-readable
# name and a validation proc that receives an aggregate and returns true
# when the rule passes.
#
#   rule = Rule.new("All PII fields must be encrypted") { |agg|
#     agg.attributes.select(&:pii?).all? { |a| a.metadata[:encrypted] }
#   }
#   rule.passes?(aggregate) # => true/false
#   rule.name               # => "All PII fields must be encrypted"
#
module Hecks
  module CustomConcerns
    class Rule
      # @return [String] human-readable rule description
      attr_reader :name

      # @param name [String] the rule description
      # @param block [Proc] validation proc that takes an aggregate, returns Boolean
      def initialize(name, &block)
        @name = name
        @block = block
      end

      # Evaluate this rule against an aggregate.
      #
      # @param aggregate [Hecks::DomainModel::Structure::Aggregate]
      # @return [Boolean] true if the rule passes
      def passes?(aggregate)
        @block.call(aggregate)
      rescue => _e
        false
      end
    end
  end
end
