# Hecks::DomainModel::Behavior::Query
#
# Intermediate representation of a domain query -- a named, reusable lookup
# defined in the DSL. Each query has a name and a block that uses the
# query DSL (where, order, limit, etc.) to build results.
#
# Part of the DomainModel IR layer. Built by the DSL aggregate builder and
# consumed by QueryGenerator to produce query classes in the domain gem.
#
#   query = Query.new(name: "Classics", block: proc { where(style: "Classic") })
#   query.name   # => "Classics"
#   query.block  # => #<Proc>
#
module Hecks
  module DomainModel
    module Behavior
    class Query
      attr_reader :name, :block

      def initialize(name:, block:)
        @name = name
        @block = block
      end
    end
    end
  end
end
