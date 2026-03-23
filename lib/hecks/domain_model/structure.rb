# Hecks::DomainModel::Structure
#
# Structural building blocks: domains, aggregates, value objects,
# attributes, validations, invariants, scopes, ports, read models, and actors.
#
module Hecks
  module DomainModel
    module Structure
      autoload :Domain,         "hecks/domain_model/structure/domain"
autoload :Aggregate,      "hecks/domain_model/structure/aggregate"
      autoload :ValueObject,    "hecks/domain_model/structure/value_object"
      autoload :Attribute,      "hecks/domain_model/structure/attribute"
      autoload :Validation,     "hecks/domain_model/structure/validation"
      autoload :Invariant,      "hecks/domain_model/structure/invariant"
      autoload :Scope,          "hecks/domain_model/structure/scope"
      autoload :PortDefinition, "hecks/domain_model/structure/port_definition"
      autoload :ReadModel,      "hecks/domain_model/structure/read_model"
      autoload :ExternalSystem, "hecks/domain_model/structure/external_system"
      autoload :Actor,          "hecks/domain_model/structure/actor"
    end
  end
end
