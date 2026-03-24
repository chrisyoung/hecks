# Hecks::DomainModel::Behavior::Specification
#
# Intermediate representation of a domain specification -- a named, reusable
# predicate defined in the DSL. Each specification has a name and a block that
# tests whether an object satisfies a business rule.
#
# Part of the DomainModel IR layer. Built by the DSL aggregate builder and
# consumed by SpecificationGenerator to produce specification classes in the
# domain gem.
#
#   spec = Specification.new(name: "HighRisk", block: proc { |loan| loan.principal > 50_000 })
#   spec.name   # => "HighRisk"
#   spec.block  # => #<Proc>
#
module Hecks
  module DomainModel
    module Behavior
    class Specification
      attr_reader :name, :block

      def initialize(name:, block:)
        @name = name
        @block = block
      end
    end
    end
  end
end
