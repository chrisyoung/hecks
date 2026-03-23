# Hecks::DomainModel::Behavior::Query
#
# Intermediate representation of a domain query — a named, reusable query
# defined in the DSL. Each query has a name and a block that uses the
# query DSL (where, order, limit, etc.) to build results.
#
#   query = Query.new(name: "Classics", block: proc { where(style: "Classic") })
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
