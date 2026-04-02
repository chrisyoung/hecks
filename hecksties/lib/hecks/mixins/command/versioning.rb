# Hecks::Command::Versioning
#
# Optimistic concurrency control for commands. When a command includes an
# +expected_version+ attribute, the VersionCheckStep compares it against the
# aggregate's current version after +#call+ returns. On mismatch, raises
# +Hecks::ConcurrencyError+. On success, bumps the aggregate version.
#
# Commands that do not supply +expected_version+ (nil) skip the check entirely,
# preserving backward compatibility.
#
# == Usage
#
#   cmd = UpdatePizza.call(pizza_id: id, name: "New Name", expected_version: 1)
#   cmd.aggregate.version  # => 2
#
module Hecks
  module Command
    module Versioning
      # Checks expected_version against the persisted aggregate's current version.
      # If the command instance does not respond to +expected_version+ or the value
      # is nil, the check is skipped (opt-in concurrency control).
      #
      # Looks up the existing aggregate in the repository to read its version,
      # since +#call+ may construct a brand-new object that starts at version 0.
      # On match, bumps the version on the aggregate returned by +#call+.
      #
      # @return [void]
      # @raise [Hecks::ConcurrencyError] when versions do not match
      def check_version
        return unless respond_to?(:expected_version, true)

        expected = expected_version
        return if expected.nil?

        agg = self.aggregate
        return unless agg&.respond_to?(:version)

        existing = find_persisted_for_version_check
        actual = existing ? existing.version : 0

        unless expected == actual
          raise Hecks::ConcurrencyError.new(
            "Version mismatch on #{agg.class.name}: expected #{expected}, got #{actual}",
            expected_version: expected,
            actual_version: actual,
            aggregate_id: agg.id
          )
        end

        agg.instance_variable_set(:@version, actual)
        agg.bump_version!
      end

      private

      # Finds the persisted aggregate by checking self-referencing references
      # first (from +reference_to+), then falling back to instance variables
      # ending in +_id+.
      #
      # @return [Object, nil] the persisted aggregate or nil
      def find_persisted_for_version_check
        id_val = resolve_self_ref_id || resolve_id_ivar
        return nil unless id_val

        repository&.find(id_val) rescue nil
      end

      # Resolves the aggregate ID from a self-referencing +reference_to+ field.
      #
      # @return [String, nil] the aggregate ID or nil
      def resolve_self_ref_id
        meta = self.class.reference_meta
        return nil unless meta&.any?

        agg_name = Hecks::Conventions::Names
                     .aggregate_module_from_command(self.class.name)
                     .split("::").last

        ref = meta.find { |r| r.type == agg_name }
        return nil unless ref

        val = respond_to?(ref.name, true) ? send(ref.name) : nil
        val.respond_to?(:id) ? val.id : val
      end

      # Falls back to scanning instance variables ending in +_id+.
      #
      # @return [String, nil] the aggregate ID or nil
      def resolve_id_ivar
        ivar = instance_variables.find { |v| v.to_s.end_with?("_id") }
        ivar ? instance_variable_get(ivar) : nil
      end
    end
  end
end
