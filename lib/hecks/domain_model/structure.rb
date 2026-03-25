# Hecks::DomainModel::Structure
#
# Namespace for the structural building blocks of a domain model: domains,
# aggregates, value objects, attributes, validations, invariants, scopes,
# ports, read models, external systems, and actors.
#
# Part of the DomainModel IR layer. Each child class is an intermediate
# representation built by the DSL and consumed by generators.
#
#   Structure::Domain         # root container holding aggregates
#   Structure::Aggregate      # DDD aggregate with commands, events, etc.
#   Structure::ValueObject    # immutable object defined by its attributes
#   Structure::Entity         # mutable sub-entity with identity (UUID)
#   Structure::Attribute      # typed field on any structure
#
module Hecks
  module DomainModel
    module Structure
      autoload :Domain,         "hecks/domain_model/structure/domain"
      autoload :Aggregate,      "hecks/domain_model/structure/aggregate"
      autoload :ValueObject,    "hecks/domain_model/structure/value_object"
      autoload :Entity,         "hecks/domain_model/structure/entity"
      autoload :Attribute,      "hecks/domain_model/structure/attribute"
      autoload :Validation,     "hecks/domain_model/structure/validation"
      autoload :Invariant,      "hecks/domain_model/structure/invariant"
      autoload :Scope,          "hecks/domain_model/structure/scope"
      autoload :PortDefinition, "hecks/domain_model/structure/port_definition"
      autoload :ReadModel,      "hecks/domain_model/structure/read_model"
      autoload :ExternalSystem, "hecks/domain_model/structure/external_system"
      autoload :Actor,          "hecks/domain_model/structure/actor"
      autoload :Lifecycle,      "hecks/domain_model/structure/lifecycle"
    end
  end
end
