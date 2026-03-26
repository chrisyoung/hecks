# Hecks::Querying::ConditionNode
#
# Tree structure for composing AND/OR query conditions. Leaf AND nodes
# hold a conditions hash; OR nodes combine two child trees. Used by
# QueryBuilder to represent composite conditions. Each adapter evaluates
# the tree via match?(obj) for in-memory or builds its own expression.
#
#   node = ConditionNode.and(style: "Classic")
#   node = node.merge(name: "Margherita")
#   combined = ConditionNode.or(node, ConditionNode.and(style: "Tropical"))
#   combined.match?(pizza)  # => true if either branch matches
#
module Hecks
  module Querying
    class ConditionNode
        attr_reader :type, :children, :conditions

        def self.and(conditions = {})
          new(type: :and, conditions: conditions)
        end

        def self.or(left, right)
          new(type: :or, children: [left, right])
        end

        def initialize(type:, conditions: {}, children: [])
          @type = type
          @conditions = conditions
          @children = children
        end

        # Merge new conditions into this node. For simple AND leaves,
        # just merge the hash. For compound nodes, wrap in a new AND.
        def merge(new_conditions)
          if type == :and && children.empty?
            self.class.new(type: :and, conditions: @conditions.merge(new_conditions))
          else
            self.class.new(type: :and, children: [self, self.class.and(new_conditions)])
          end
        end

        # True if this is a simple AND with no children (flat hash).
        def simple?
          type == :and && children.empty?
        end

        # Evaluate the condition tree against an object (in-memory).
        def match?(obj)
          case type
          when :and
            cond_match = conditions.all? do |k, v|
              next false unless obj.respond_to?(k)
              actual = obj.send(k)
              v.is_a?(Operators::Operator) ? v.match?(actual) : actual == v
            end
            cond_match && children.all? { |c| c.match?(obj) }
          when :or
            children.any? { |c| c.match?(obj) }
          end
        end
      end
  end
end
