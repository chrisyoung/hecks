# Hecks::DomainModel::Behavior
#
# Namespace for domain behavior representations: commands (intent to change
# state), events (records of what happened), policies (reactive rules and
# guards), and queries (named lookups).
#
# Part of the DomainModel IR layer. Each child class is an intermediate
# representation built by the DSL and consumed by generators.
#
#   Behavior::Command      # intent to change state
#   Behavior::DomainEvent  # record that something happened
#   Behavior::Policy       # reactive rule or guard block
#   Behavior::Query        # named, reusable lookup
#
module Hecks
  module DomainModel
    module Behavior
      autoload :Command,     "hecks/domain_model/behavior/command"
      autoload :DomainEvent, "hecks/domain_model/behavior/domain_event"
      autoload :Policy,      "hecks/domain_model/behavior/policy"
      autoload :Query,            "hecks/domain_model/behavior/query"
      autoload :EventSubscriber, "hecks/domain_model/behavior/event_subscriber"
      autoload :Specification,   "hecks/domain_model/behavior/specification"
      autoload :Service,         "hecks/domain_model/behavior/service"
    end
  end
end
