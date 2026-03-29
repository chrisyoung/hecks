# Hecks::MultiDomain::Validator
#
# Rejects reference_to attributes that cross domain boundaries.
# Cross-domain references must use plain String IDs, not reference_to.
#
#   Hecks::MultiDomain::Validator.validate_no_cross_domain_references(domains)
#
module Hecks
  module MultiDomain
    module Validator
      extend HecksTemplating::NamingHelpers
      module_function

      def validate_no_cross_domain_references(domains)
        errors = []
        domains.each do |domain|
          own_aggs = domain.aggregates.map(&:name)
          domain.aggregates.each do |agg|
            agg.attributes.select(&:reference?).each do |attr|
              ref_name = attr.type.to_s
              next if own_aggs.include?(ref_name)
              owner = domains.find { |d| d.aggregates.any? { |a| a.name == ref_name } }
              if owner
                errors << "#{domain.name}::#{agg.name} uses reference_to(\"#{ref_name}\") " \
                          "which belongs to #{owner.name}. Use: attribute :#{domain_snake_name(ref_name)}_id, String"
              end
            end
          end
        end
        unless errors.empty?
          raise Hecks::ValidationError, "Cross-domain reference_to detected:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
        end
      end
    end
  end
end
