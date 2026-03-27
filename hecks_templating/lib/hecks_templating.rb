# = HecksTemplating
#
# Shared contracts and template generation infrastructure for Hecks.
# Defines data shapes that multiple code paths must agree on — view
# templates, type mappings, event shapes, migration fidelity. Consumed
# by Go, Ruby, and SQL generators to prevent cross-target drift.
#
#   require "hecks_templating"
#   Hecks::ViewContract::CONFIG[:fields]
#
require_relative "hecks_templating/view_contract"
require_relative "hecks_templating/type_contract"
require_relative "hecks_templating/event_contract"
require_relative "hecks_templating/migration_contract"
require_relative "hecks_templating/smoke_test"
