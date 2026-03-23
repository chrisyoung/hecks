# Hecks::Services::Querying::Operators
#
# Comparison operator wrappers for the query DSL. Used as values in
# where conditions to express comparisons beyond equality.
#
#   where(price: Operators::Gt.new(10))
#   where(status: Operators::NotEq.new("cancelled"))
#   where(style: Operators::In.new(["Classic", "Tropical"]))
#
module Hecks
  module Services
    module Querying
      module Operators
        class Gt
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual > @value
          def sequel_expr(column) = Sequel.expr(column) > @value
        end

        class Gte
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual >= @value
          def sequel_expr(column) = Sequel.expr(column) >= @value
        end

        class Lt
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual < @value
          def sequel_expr(column) = Sequel.expr(column) < @value
        end

        class Lte
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual <= @value
          def sequel_expr(column) = Sequel.expr(column) <= @value
        end

        class NotEq
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = actual != @value
          def sequel_expr(column) = Sequel.negate(column => @value)
        end

        class In
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = @value.include?(actual)
          def sequel_expr(column) = Sequel.expr(column => @value)
        end
      end
    end
  end
end
