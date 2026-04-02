# Hecks::DSL::AggregateBuilder::QueryMethods
#
# Scope, query, and index DSL methods extracted from AggregateBuilder.
#
module Hecks
  module DSL
    class AggregateBuilder
      module QueryMethods
        # Define a named query scope with conditions or a lambda.
        #
        # @param name [Symbol] the scope name
        # @param conditions_or_lambda [Hash, Proc, nil] filter conditions
        # @yield optional block used as conditions
        # @return [void]
        def scope(name, conditions_or_lambda = nil, &block)
          conditions = block || conditions_or_lambda
          @scopes << DomainModel::Structure::Scope.new(name: name, conditions: conditions)
        end

        # Define a custom query with a block.
        #
        # @param name [Symbol] the query name
        # @yield block implementing the query logic
        # @return [void]
        def query(name, &block)
          @queries << DomainModel::Behavior::Query.new(name: name, block: block)
        end

        # Define a custom finder on this aggregate's repository.
        #
        # A finder declares a named lookup method with typed parameters.
        # The memory adapter auto-generates an equality-match implementation;
        # custom adapters get a NotImplementedError stub in the port module.
        #
        # @param name [Symbol] the finder method name (e.g., :by_email)
        # @param params [Array<Symbol>] attribute names to match against
        # @return [void]
        def finder(name, *params)
          @finders << DomainModel::Structure::Finder.new(name: name, params: params.map(&:to_sym))
        end
      end
    end
  end
end
