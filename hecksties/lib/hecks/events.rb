# = Hecks::Events
#
# Namespace for event versioning and upcasting infrastructure.
# Provides a registry for mapping [event_type, version] to transform
# procs, and an engine that chains transforms to upcast stored events
# to their current schema version.
#
#   Hecks::Events::UpcasterRegistry.new
#   Hecks::Events::UpcasterEngine.new(registry)
#
module Hecks
  module Events
    require_relative "events/upcaster_registry"
    require_relative "events/upcaster_engine"
    require_relative "events/build_engine"
  end
end
