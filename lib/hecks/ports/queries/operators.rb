# Hecks::Querying::Operators
#
# Comparison operator wrappers for the query DSL. Used as values in
# where conditions to express comparisons beyond equality. Each operator
# implements match?(actual) for in-memory filtering. SQL translation is
# handled by the SQL adapter, not here — keeping the domain layer pure.
# All operators include the Operator marker module for adapter detection.
#
#   where(price: Operators::Gt.new(10))
#   where(status: Operators::NotEq.new("cancelled"))
#   where(style: Operators::In.new(["Classic", "Tropical"]))
#
module Hecks
  module Querying
    module Operators
        # Marker module so adapters can detect operator values
        module Operator; end

        class Gt
          include Operator
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual > @value
        end

        class Gte
          include Operator
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual >= @value
        end

        class Lt
          include Operator
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual < @value
        end

        class Lte
          include Operator
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = !actual.nil? && actual <= @value
        end

        class NotEq
          include Operator
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = actual != @value
        end

        class In
          include Operator
          attr_reader :value
          def initialize(value) = @value = value
          def match?(actual) = @value.include?(actual)
        end
      end
  end
end
