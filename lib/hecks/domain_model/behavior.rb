# Hecks::DomainModel::Behavior
#
# Domain behavior representations: commands (intent), events (facts),
# policies (reactive rules), and queries (named lookups).
#
module Hecks
  module DomainModel
    module Behavior
      autoload :Command,     "hecks/domain_model/behavior/command"
      autoload :DomainEvent, "hecks/domain_model/behavior/domain_event"
      autoload :Policy,      "hecks/domain_model/behavior/policy"
      autoload :Query,       "hecks/domain_model/behavior/query"
    end
  end
end
