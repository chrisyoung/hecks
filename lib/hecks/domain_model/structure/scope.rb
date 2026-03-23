# Hecks::DomainModel::Structure::Scope
#
# Value object representing a named query scope declared on an aggregate.
# A scope has a name and conditions -- either a plain Hash for simple
# equality filters, or a Proc/lambda for parameterized queries.
#
#   Scope.new(name: :active, conditions: { status: "active" })
#   Scope.new(name: :by_name, conditions: ->(name) { { name: name } })
#
module Hecks
  module DomainModel
    module Structure
    class Scope
      attr_reader :name, :conditions

      def initialize(name:, conditions:)
        @name = name
        @conditions = conditions
      end

      def callable?
        conditions.is_a?(Proc)
      end
    end
    end
  end
end
