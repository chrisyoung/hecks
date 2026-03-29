# = HecksTemplating
#
# Shared contracts and template generation infrastructure for Hecks.
# Defines data shapes that multiple code paths must agree on — view
# templates, type mappings, event shapes, migration fidelity. Consumed
# by Go, Ruby, and SQL generators to prevent cross-target drift.
#
#   require "hecks_templating"
#   HecksTemplating::ViewContract::CONFIG[:fields]
#
require_relative "hecks_templating/view_contract"
require_relative "hecks_templating/type_contract"
require_relative "hecks_templating/event_contract"
require_relative "hecks_templating/event_log_contract"
require_relative "hecks_templating/form_parsing_contract"
require_relative "hecks_templating/ui_label_contract"
require_relative "hecks_templating/aggregate_contract"
require_relative "hecks_templating/display_contract"
require_relative "hecks_templating/migration_contract"
require_relative "hecks_templating/naming_contract"
require_relative "hecks_templating/naming_helpers"
require_relative "hecks_templating/smoke_test"
