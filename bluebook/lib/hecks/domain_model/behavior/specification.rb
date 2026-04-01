module Hecks
  module DomainModel
    module Behavior

    # Hecks::DomainModel::Behavior::Specification
    #
    # Intermediate representation of a domain specification -- a named, reusable
    # predicate defined in the DSL. Each specification has a name, an optional
    # human-readable description, and a block that tests whether an object
    # satisfies a business rule.
    #
    # Specifications are used in two contexts:
    # 1. Directly, to filter or validate domain objects (e.g. "is this loan high risk?")
    # 2. In workflows, as branch conditions that determine which execution path to take
    #
    # Part of the DomainModel IR layer. Built by the DSL aggregate builder and
    # consumed by SpecificationGenerator to produce specification classes in the
    # domain gem. At runtime, the block is called with a domain object and returns
    # a boolean.
    #
    #   spec = Specification.new(name: "HighRisk", description: "Loans over $50k")
    #   spec.name        # => "HighRisk"
    #   spec.description # => "Loans over $50k"
    #
    class Specification
      # @return [String] PascalCase specification name (e.g. "HighRisk", "IsActive")
      # @return [String, nil] human-readable description of the business rule
      # @return [Proc, nil] predicate block that receives a domain object and returns
      #   true/false indicating whether the object satisfies this specification
      attr_reader :name, :description, :block

      # Creates a new Specification IR node.
      #
      # @param name [String] PascalCase specification name (e.g. "HighRisk")
      # @param description [String, nil] human-readable description of the rule
      # @param block [Proc, nil] predicate callable that receives a domain object
      #   and returns truthy/falsy
      # @return [Specification]
      def initialize(name:, description: nil, block: nil)
        @name = name
        @description = description
        @block = block
      end
    end
    end
  end
end
