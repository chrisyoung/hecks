# Hecks::ValidationRules::References::FanOut
#
# Warns when a single aggregate has too many outgoing references (fan-out).
# An aggregate with 4 or more references is likely taking on too many
# responsibilities and should be split into smaller aggregates.
#
# All findings are warnings (non-blocking), not errors.
#
#   rule = FanOut.new(domain)
#   rule.errors   # => []
#   rule.warnings # => ["Order has 5 outgoing references (threshold: 4) ..."]
#
module Hecks
  module ValidationRules
    module References
      class FanOut < BaseRule
        THRESHOLD = 4

        def errors
          []
        end

        def warnings
          @domain.aggregates.filter_map do |agg|
            refs = (agg.references || []).reject(&:domain)
            next unless refs.size >= THRESHOLD

            "#{agg.name} has #{refs.size} outgoing references (threshold: #{THRESHOLD}). " \
            "This aggregate may have too many responsibilities -- consider splitting it."
          end
        end
      end
      Hecks.register_validation_rule(FanOut)
    end
  end
end
