# = HecksTemplating
#
# Shared view contracts and template generation infrastructure for Hecks.
# Defines the data shape each web explorer view expects, consumed by
# both Go and Ruby generators to keep struct fields and template
# bindings in sync.
#
#   require "hecks_templating"
#   Hecks::ViewContracts::CONFIG[:fields]
#
require_relative "hecks_templating/view_contracts"
require_relative "hecks_templating/smoke_test"
