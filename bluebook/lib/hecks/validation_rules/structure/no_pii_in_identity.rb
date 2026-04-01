# Hecks::ValidationRules::Structure::NoPiiInIdentity
#
# Validates that identity fields don't contain PII attributes.
# Including PII in composed identifiers leaks sensitive data into
# foreign keys, logs, URLs, and event streams.
#
module Hecks
  module ValidationRules
    module Structure
      class NoPiiInIdentity < BaseRule
        def errors
          issues = []
          @domain.aggregates.each do |agg|
            next unless agg.identity_fields
            agg.identity_fields.each do |field|
              attr = agg.attributes.find { |a| a.name == field }
              next unless attr&.pii?
              issues << "#{agg.name} uses PII attribute :#{field} in identity. " \
                        "PII must not be part of composed identity keys."
            end
          end
          issues
        end
      end
      Hecks.register_validation_rule(NoPiiInIdentity)
    end
  end
end
