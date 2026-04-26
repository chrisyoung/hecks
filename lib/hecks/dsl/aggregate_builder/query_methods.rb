# Hecks::DSL::AggregateBuilder::QueryMethods
#
# Scope and query DSL methods extracted from AggregateBuilder.
#
# [antibody-exempt: lib/hecks/dsl/aggregate_builder/query_methods.rb —
#  evaluates the query block via QueryBuilder so predicate queries (i107)
#  produce the same canonical IR (description / givens / returns) as the
#  Rust parser. Same i80 retirement contract.]
#
module Hecks
  module DSL
    class AggregateBuilder
      module QueryMethods
        # Define a named query scope with conditions or a lambda.
        def scope(name, conditions_or_lambda = nil, &block)
          conditions = block || conditions_or_lambda
          @scopes << BluebookModel::Structure::Scope.new(name: name, conditions: conditions)
        end

        # Define a custom query with a block. Predicate queries (i107)
        # may declare `description`, `returns`, and `given { … }` in the
        # block body — the QueryDeclarationBuilder captures them.
        # Descriptive queries pass through unchanged.
        def query(name, &block)
          builder = QueryDeclarationBuilder.new
          builder.instance_eval(&block) if block
          @queries << BluebookModel::Behavior::Query.new(
            name: name,
            block: block,
            description: builder.description_text,
            givens: builder.givens,
            returns: builder.returns_type,
          )
        end
      end

      # Captures the declarative half of a `query "Foo" do … end` block
      # so the IR mirrors what the Rust parser extracts. Methods other
      # than the four below are no-ops at IR-build time — the block is
      # ALSO stored on the Query so the QueryBuilder runtime path keeps
      # working for descriptive (where/order/limit) queries.
      class QueryDeclarationBuilder
        attr_reader :description_text, :givens, :returns_type

        def initialize
          @description_text = nil
          @givens = []
          @returns_type = nil
        end

        def description(text = nil)
          @description_text = text if text
        end

        def goal(text = nil)
          @description_text = text if text
        end

        def returns(type)
          @returns_type = type.is_a?(String) ? type : type.to_s
        end

        def given(message = nil, &expr_block)
          # Capture the message and a placeholder expression. Ruby
          # doesn't introspect the block source ; the canonical IR's
          # parity check uses Rust's expression text, and Ruby falls
          # back to the message (or nil) for the expression. The runtime
          # ignores Ruby's expression — predicate evaluation is Rust.
          msg = message
          @givens << BluebookModel::Behavior::Given.new(
            expression: msg.to_s,
            message: msg,
          )
        end

        # Soak up unknown DSL calls without raising — descriptive queries
        # (where/order/limit/...) lean on this so they don't fail when
        # evaluated at IR-build time.
        def method_missing(_name, *_args, **_kwargs, &_block)
          self
        end

        def respond_to_missing?(_name, _private = false)
          true
        end
      end
    end
  end
end
