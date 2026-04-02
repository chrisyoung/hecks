module Hecks
  module ValidationRules
    module WorldConcerns

      # Hecks::ValidationRules::WorldConcerns::Sustainability
      #
      # When the :sustainability concern is declared, checks that aggregates
      # with data that could grow unboundedly have lifecycle management and
      # expiration attributes. Specifically:
      #
      # - Warns if an aggregate has no lifecycle (no way to archive/retire data)
      # - Warns if an aggregate lacks an expiration-like attribute
      #   (expires_at, expiration, ttl, retention)
      #
      # These are always warnings, never errors -- they encourage sustainable
      # data management patterns without blocking development.
      #
      #   world_concerns :sustainability
      #
      #   aggregate "Session" do
      #     attribute :token, String
      #     # warning: no lifecycle defined
      #     # warning: no expiration attribute
      #   end
      #
      class Sustainability < BaseRule
        EXPIRATION_PATTERNS = %w[
          expires_at expiration ttl retention retired_at archived_at
        ].freeze

        def errors
          return [] unless @domain.world_concerns.include?(:sustainability)

          issues = []
          @domain.aggregates.each do |agg|
            check_lifecycle(agg, issues)
            check_expiration(agg, issues)
          end
          issues
        end

        private

        def check_lifecycle(agg, issues)
          return if agg.lifecycle

          issues << error(
            "Sustainability: #{agg.name} has no lifecycle",
            hint: "Add a lifecycle to manage data retention: lifecycle :status, default: \"active\""
          )
        end

        def check_expiration(agg, issues)
          attr_names = agg.attributes.map { |a| a.name.to_s }
          has_expiration = EXPIRATION_PATTERNS.any? { |pat| attr_names.any? { |n| n.include?(pat) } }
          return if has_expiration

          issues << error(
            "Sustainability: #{agg.name} has no expiration attribute",
            hint: "Add an expiration field: attribute :expires_at, DateTime"
          )
        end
      end
      Hecks.register_validation_rule(Sustainability)
    end
  end
end
