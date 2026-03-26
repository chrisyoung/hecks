# Hecks::Boot::CrossDomainValidator
#
# Rejects reference_to attributes that cross domain boundaries.
# Cross-domain references must use plain String IDs, not reference_to.
# Enforces that bounded contexts stay decoupled (no shared kernel).
#
#   CrossDomainValidator.validate!(domains)
#
module Hecks
  module Boot
    module CrossDomainValidator
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
                          "which belongs to #{owner.name}. Cross-domain references must use " \
                          "plain String IDs, not reference_to. Use: attribute :#{Hecks::Utils.underscore(ref_name)}_id, String"
              end
            end
          end
        end
        unless errors.empty?
          raise Hecks::ValidationError, "Shared kernel pattern detected (cross-domain reference_to):\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
        end
      end
    end
  end
end
