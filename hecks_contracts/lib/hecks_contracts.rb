# = HecksContracts
#
# Data contracts that guarantee cross-target consistency.
# Every generator (Ruby, Go, Rails, static) consumes these
# contracts instead of maintaining its own type/display/form logic.
#
module Hecks
  module Contracts
    autoload :TypeContract,        "hecks_contracts/type_contract"
    autoload :DisplayContract,     "hecks_contracts/display_contract"
    autoload :ViewContract,        "hecks_contracts/view_contract"
    autoload :EventContract,       "hecks_contracts/event_contract"
    autoload :EventLogContract,    "hecks_contracts/event_log_contract"
    autoload :FormParsingContract, "hecks_contracts/form_parsing_contract"
    autoload :AggregateContract,   "hecks_contracts/aggregate_contract"
    autoload :NamingContract,      "hecks_contracts/naming_contract"
    autoload :MigrationContract,   "hecks_contracts/migration_contract"
    autoload :UILabelContract,     "hecks_contracts/ui_label_contract"
  end
end
