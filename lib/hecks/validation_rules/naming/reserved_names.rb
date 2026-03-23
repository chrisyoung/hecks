# Hecks::ValidationRules::Naming::ReservedNames
#
# Rejects attribute names that are Ruby keywords, and aggregate names
# that would produce invalid Ruby constants. Reserved attribute names
# (id, created_at, updated_at) are allowed but produce build warnings.
#
module Hecks
  module ValidationRules
    module Naming
    class ReservedNames < BaseRule
      def errors
        errs = []
        @domain.aggregates.each do |agg|
          errs.concat(check_aggregate_name(agg))
          errs.concat(check_keyword_attrs(agg))
        end
        errs
      end

      # Returns warnings (not errors) for reserved attribute names.
      # Called by Hecks.build to emit non-blocking warnings.
      def self.reserved_attr_warnings(domain)
        warnings = []
        domain.aggregates.each do |agg|
          agg.attributes.each do |attr|
            if Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(attr.name.to_s)
              warnings << "#{agg.name} attribute '#{attr.name}' overrides auto-generated attribute — make sure this is intentional"
            end
          end
        end
        warnings
      end

      private

      def check_aggregate_name(agg)
        errs = []
        unless agg.name =~ /\A[A-Z][a-zA-Z0-9]*\z/
          errs << "Invalid aggregate name '#{agg.name}': must start with uppercase letter and contain only alphanumeric characters"
        end
        errs
      end

      def check_keyword_attrs(agg)
        errs = []
        agg.attributes.each do |attr|
          if Hecks::Utils.ruby_keyword?(attr.name.to_s)
            errs << "#{agg.name} attribute '#{attr.name}' is a Ruby keyword — use a different name"
          end
        end
        errs
      end
    end
    end
  end
end
