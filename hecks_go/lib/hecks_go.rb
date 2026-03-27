# = HecksGo
#
# Go domain generator for Hecks. Produces a complete Go project from
# the same domain IR the Ruby generators read. Same DSL, Go output.
#
# == Usage
#
#   require "hecks_go"
#   domain = Hecks.domain("Pizzas") { ... }
#   HecksGo::ProjectGenerator.new(domain).generate
#
#   # Or via CLI:
#   hecks build --target go
#
require_relative "hecks_go/go_utils"
require_relative "hecks_go/generators/aggregate_generator"
require_relative "hecks_go/generators/value_object_generator"
require_relative "hecks_go/generators/command_generator"
require_relative "hecks_go/generators/event_generator"
require_relative "hecks_go/generators/port_generator"
require_relative "hecks_go/generators/memory_adapter_generator"
require_relative "hecks_go/generators/errors_generator"
require_relative "hecks_go/generators/server_generator"
require_relative "hecks_go/generators/project_generator"
