# Hecks::EventStorm::Result
#
# Return value from Hecks.from_event_storm. Contains the built Domain object,
# the generated DSL string, and any warnings produced during parsing.
#
#   result = Hecks.from_event_storm("storm.md")
#   result.domain    # => DomainModel::Structure::Domain
#   result.dsl       # => "Hecks.domain \"Ordering\" do ..."
#   result.warnings  # => ["Event 'Order Placed' doesn't match ..."]
#
module Hecks
  module EventStorm
    class Result
      attr_reader :domain, :dsl, :warnings

      def initialize(domain:, dsl:, warnings: [])
        @domain = domain
        @dsl = dsl
        @warnings = warnings
      end
    end
  end
end
