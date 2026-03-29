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
    # Validates that no aggregate in one domain uses +reference_to+ to reference
    # an aggregate that belongs to a different domain. This enforces the bounded
    # context pattern: domains must communicate through events and plain String IDs,
    # not through direct object references.
    #
    # When a cross-domain +reference_to+ is detected, the validator raises a
    # +Hecks::ValidationError+ with a detailed message explaining which attribute
    # violates the rule and suggesting the correct approach (plain String ID).
    #
    # This module is included in +Hecks::Boot+ and called during +boot_multi+
    # before any domain is loaded.
    module CrossDomainValidator
      include Hecks::NamingHelpers
      # Scans all domains for +reference_to+ attributes that point to aggregates
      # in other domains. Collects all violations and raises a single error with
      # all violations listed if any are found.
      #
      # @param domains [Array<Hecks::DomainModel::Structure::Domain>] all domains in the multi-domain setup
      # @return [void]
      # @raise [Hecks::ValidationError] if any cross-domain +reference_to+ attributes are found,
      #   with a message listing each violation and the suggested fix
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
                          "plain String IDs, not reference_to. Use: attribute :#{domain_snake_name(ref_name)}_id, String"
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
