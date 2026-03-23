# Hecks::DomainModel::Domain
#
# The root of the domain model intermediate representation. A domain contains
# one or more bounded contexts, each holding aggregates. For backward
# compatibility, aggregates can be passed directly (they go into an implicit
# "Default" context).
#
# With contexts:
#
#   domain = Domain.new(name: "Pizzas", contexts: [ordering_ctx, kitchen_ctx])
#   domain.contexts          # => [ordering_ctx, kitchen_ctx]
#   domain.aggregates        # => all aggregates across all contexts
#   domain.single_context?   # => false
#
# Without contexts (backward compatible):
#
#   domain = Domain.new(name: "Pizzas", aggregates: [pizza_agg, order_agg])
#   domain.contexts          # => [#<BoundedContext "Default">]
#   domain.aggregates        # => [pizza_agg, order_agg]
#   domain.single_context?   # => true
#
module Hecks
  module DomainModel
    module Structure
    class Domain
      attr_reader :name, :contexts

      def initialize(name:, aggregates: [], contexts: [])
        @name = name
        if contexts.any?
          @contexts = contexts
        else
          @contexts = [BoundedContext.new(name: "Default", aggregates: aggregates)]
        end
      end

      # All aggregates across all contexts (backward compatible)
      def aggregates
        @contexts.flat_map(&:aggregates)
      end

      # True when there's only one context (default or single explicit)
      # Determines hoisting and repository access behavior
      def single_context?
        @contexts.size == 1
      end

      # True when the user explicitly defined context blocks
      def has_explicit_contexts?
        !(@contexts.size == 1 && @contexts.first.default?)
      end

      def find_context(name)
        @contexts.find { |c| c.name == name }
      end

      def module_name
        name.gsub(/\s+/, "")
      end

      def gem_name
        Hecks::Utils.underscore(module_name) + "_domain"
      end
    end
    end
  end
end
