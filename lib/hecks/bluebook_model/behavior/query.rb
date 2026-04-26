module Hecks
  module BluebookModel
    module Behavior

    # Hecks::BluebookModel::Behavior::Query
    #
    # Intermediate representation of a domain query -- a named, reusable lookup
    # defined in the DSL. Each query has a name and a block that uses the
    # query DSL (where, order, limit, etc.) to build results.
    #
    # At runtime, queries are executed against the repository via QueryBuilder,
    # which evaluates the block in a context that supports filtering, ordering,
    # and pagination methods.
    #
    # Predicate-style queries (i107) carry givens + returns + description so
    # the runtime can evaluate them as kernel-surface invariants. Ruby
    # parity-tests rely on these accessors returning the same shape Rust
    # extracts.
    #
    # [antibody-exempt: lib/hecks/bluebook_model/behavior/query.rb — adds
    #  description / givens / returns accessors so the DSL `query "Foo"
    #  do given { … } end` shape produces the same canonical IR as the
    #  Rust parser. Same i80 retirement contract.]
    #
    #   query = Query.new(name: "Classics", block: proc { where(style: "Classic") })
    #   query.name   # => "Classics"
    #   query.block  # => #<Proc>
    #
    class Query
      attr_reader :name, :block, :description, :givens, :returns

      def initialize(name:, block:, description: nil, givens: [], returns: nil)
        @name = name
        @block = block
        @description = description
        @givens = givens
        @returns = returns
      end
    end
    end
  end
end
