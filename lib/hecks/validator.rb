# Hecks::Validator
#
# Validates a domain model for DDD consistency. Enforces aggregate boundaries,
# reference rules, command/event structure, policy wiring, and naming conventions.
#
#   validator = Validator.new(domain)
#   validator.valid?   # => true/false
#   validator.errors   # => ["Order references unknown aggregate: Widget"]
#
# Rules enforced:
#   - No duplicate aggregate names
#   - References must target aggregate roots
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
      ValidationRules::Naming::UniqueAggregateNames,
      ValidationRules::Naming::NameCollisions,
      ValidationRules::Naming::CommandNaming,
      ValidationRules::References::ValidReferences,
      ValidationRules::References::NoBidirectionalReferences,
      ValidationRules::References::NoSelfReferences,
      ValidationRules::References::NoValueObjectReferences,
      ValidationRules::Structure::AggregatesHaveCommands,
      ValidationRules::Structure::CommandsHaveAttributes,
      ValidationRules::Structure::ValidPolicyEvents,
      ValidationRules::Structure::ValidPolicyTriggers,
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
