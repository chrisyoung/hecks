# Hecks::Validator
#
# Validates a domain model for DDD consistency. Enforces aggregate boundaries,
# reference rules, command/event structure, policy wiring, naming conventions,
# and bounded context separation.
#
#   validator = Validator.new(domain)
#   validator.valid?   # => true/false
#   validator.errors   # => ["Order references unknown aggregate: Widget"]
#
# Rules enforced:
#   - No duplicate context or aggregate names
#   - References must target aggregate roots within the same context
#   - No bidirectional references between aggregates
#   - No self-references on aggregates
#   - Value objects must not contain references
#   - Aggregates must have at least one command
#   - Command names should be verb phrases
#   - Policy events must exist, policy triggers must name existing commands
#   - Aggregate and value object names must not collide
#
module Hecks
  class Validator
    RULES = [
      ValidationRules::UniqueContextNames,
      ValidationRules::UniqueAggregateNames,
      ValidationRules::NameCollisions,
      ValidationRules::ValidReferences,
      ValidationRules::NoBidirectionalReferences,
      ValidationRules::NoSelfReferences,
      ValidationRules::NoValueObjectReferences,
      ValidationRules::AggregatesHaveCommands,
      ValidationRules::CommandNaming,
      ValidationRules::CommandsHaveAttributes,
      ValidationRules::ValidPolicyEvents,
      ValidationRules::ValidPolicyTriggers,
    ].freeze

    attr_reader :errors

    def initialize(domain)
      @domain = domain
      @errors = []
    end

    def valid?
      @errors = RULES.flat_map { |rule| rule.new(@domain).errors }
      @errors.empty?
    end
  end
end
