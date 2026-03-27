# = HecksStandalone
#
# Standalone domain generator for Hecks. Produces a complete, self-contained
# Ruby project with zero runtime dependency on the hecks gem. The output
# includes an inlined runtime, HTTP server with UI, and all domain code.
#
# == Usage
#
#   require "hecks_standalone"
#   domain = Hecks.domain("Pizzas") { ... }
#   HecksStandalone::GemGenerator.new(domain).generate
#
#   # Or via CLI:
#   hecks domain build --standalone
#
require_relative "hecks_standalone/generators/runtime_writer"
require_relative "hecks_standalone/generators/entry_point_generator"
require_relative "hecks_standalone/generators/server_generator"
require_relative "hecks_standalone/generators/ui_generator"
require_relative "hecks_standalone/generators/gem_generator"
