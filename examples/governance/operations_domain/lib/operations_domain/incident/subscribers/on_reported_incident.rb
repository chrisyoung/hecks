module OperationsDomain
  class Incident
    module Subscribers
      class OnReportedIncident
        EVENT = "ReportedIncident"
        ASYNC = true

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          # Side-effect: page on-call when critical incident reported
        end
      end
    end
  end
end
