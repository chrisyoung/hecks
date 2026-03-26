# Hecks::Querying::Operators
#
# Comparison operator wrappers for the query DSL. Used as values in
# +where+ conditions to express comparisons beyond simple equality.
# Each operator implements +match?(actual)+ for in-memory filtering.
# SQL translation is handled by the SQL adapter, not here -- keeping
# the domain layer pure. All operators include the Operator marker
# module so adapters can detect operator values vs. literal equality.
#
# == Available Operators
#
# - Gt -- greater than (+>+)
# - Gte -- greater than or equal (+>=+)
# - Lt -- less than (+<+)
# - Lte -- less than or equal (+<=+)
# - NotEq -- not equal (+!=+)
# - In -- inclusion in a collection (+IN+)
#
# == Usage
#
#   Pizza.where(price: Operators::Gt.new(10))
#   Pizza.where(status: Operators::NotEq.new("cancelled"))
#   Pizza.where(style: Operators::In.new(["Classic", "Tropical"]))
#
module Hecks
  module Querying
    module Operators
        # Marker module included by all operator classes. Adapters check
        # +value.is_a?(Operators::Operator)+ to distinguish operator objects
        # from literal equality values in condition hashes.
        module Operator; end

        # Greater-than comparison operator.
        # Matches when the actual value is strictly greater than the threshold.
        #
        # @example
        #   Gt.new(10).match?(15)  # => true
        #   Gt.new(10).match?(10)  # => false
        #   Gt.new(10).match?(nil) # => false
        class Gt
          include Operator
          # @return [Object] the threshold value to compare against
          attr_reader :value
          # @param value [Comparable] the threshold value
          def initialize(value) = @value = value
          # @param actual [Comparable, nil] the value to test
          # @return [Boolean] true if actual > value
          def match?(actual) = !actual.nil? && actual > @value
        end

        # Greater-than-or-equal comparison operator.
        # Matches when the actual value is greater than or equal to the threshold.
        #
        # @example
        #   Gte.new(10).match?(10) # => true
        #   Gte.new(10).match?(9)  # => false
        class Gte
          include Operator
          # @return [Object] the threshold value to compare against
          attr_reader :value
          # @param value [Comparable] the threshold value
          def initialize(value) = @value = value
          # @param actual [Comparable, nil] the value to test
          # @return [Boolean] true if actual >= value
          def match?(actual) = !actual.nil? && actual >= @value
        end

        # Less-than comparison operator.
        # Matches when the actual value is strictly less than the threshold.
        #
        # @example
        #   Lt.new(10).match?(5)   # => true
        #   Lt.new(10).match?(10)  # => false
        class Lt
          include Operator
          # @return [Object] the threshold value to compare against
          attr_reader :value
          # @param value [Comparable] the threshold value
          def initialize(value) = @value = value
          # @param actual [Comparable, nil] the value to test
          # @return [Boolean] true if actual < value
          def match?(actual) = !actual.nil? && actual < @value
        end

        # Less-than-or-equal comparison operator.
        # Matches when the actual value is less than or equal to the threshold.
        #
        # @example
        #   Lte.new(10).match?(10)  # => true
        #   Lte.new(10).match?(11)  # => false
        class Lte
          include Operator
          # @return [Object] the threshold value to compare against
          attr_reader :value
          # @param value [Comparable] the threshold value
          def initialize(value) = @value = value
          # @param actual [Comparable, nil] the value to test
          # @return [Boolean] true if actual <= value
          def match?(actual) = !actual.nil? && actual <= @value
        end

        # Not-equal comparison operator.
        # Matches when the actual value differs from the reference value.
        # Unlike other operators, nil actual values DO match (nil != "something").
        #
        # @example
        #   NotEq.new("cancelled").match?("active")    # => true
        #   NotEq.new("cancelled").match?("cancelled")  # => false
        #   NotEq.new("cancelled").match?(nil)           # => true
        class NotEq
          include Operator
          # @return [Object] the value to compare against
          attr_reader :value
          # @param value [Object] the value that should NOT match
          def initialize(value) = @value = value
          # @param actual [Object, nil] the value to test
          # @return [Boolean] true if actual != value
          def match?(actual) = actual != @value
        end

        # Inclusion operator.
        # Matches when the actual value is contained in the given collection.
        #
        # @example
        #   In.new(["Classic", "Tropical"]).match?("Classic")  # => true
        #   In.new(["Classic", "Tropical"]).match?("Hawaiian") # => false
        class In
          include Operator
          # @return [Array, #include?] the collection of allowed values
          attr_reader :value
          # @param value [Array, #include?] the collection of allowed values
          def initialize(value) = @value = value
          # @param actual [Object] the value to test for inclusion
          # @return [Boolean] true if the collection includes actual
          def match?(actual) = @value.include?(actual)
        end
      end
  end
end
