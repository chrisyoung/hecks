# Hecks::ValidationRules::CustomConcerns
#
# Validation rule that checks declared custom concerns against aggregates.
# When a domain declares custom concerns (via `concerns :hipaa_compliance`),
# each concern's rules are evaluated against every aggregate. Failures are
# reported as validation errors.
#
#   Hecks.concern(:hipaa) { rule("PII hidden") { |a| true } }
#   domain = Hecks.domain("Health") { concerns :hipaa; ... }
#   validator = Hecks::Validator.new(domain)
#   validator.valid?
#
module Hecks
  module ValidationRules
    class CustomConcerns < BaseRule
      def errors
        return [] unless @domain.respond_to?(:custom_concerns)
        return [] if @domain.custom_concerns.empty?

        issues = []
        @domain.custom_concerns.each do |name|
          concern = Hecks.find_concern(name)
          next unless concern

          @domain.aggregates.each do |agg|
            concern.rules.each do |rule|
              unless rule.passes?(agg)
                issues << error("CustomConcern[#{name}]: #{agg.name} -- #{rule.name}",
                  hint: "Fix the aggregate to satisfy the '#{name}' concern rule")
              end
            end
          end
        end
        issues
      end
    end
    Hecks.register_validation_rule(CustomConcerns)
  end
end
