# Hecks::DomainDiff
#
# Compares two domain snapshots and produces a list of Change objects
# describing what was added, removed, or modified. Adapter-agnostic —
# the changes are structural, not tied to any persistence format.
#
# Used by Session#apply! to detect what changed and feed changes to
# registered MigrationStrategies.
#
#   old_domain = Hecks.domain("Pizzas") { ... }
#   new_domain = Hecks.domain("Pizzas") { ... }
#   changes = DomainDiff.call(old_domain, new_domain)
#   # => [AddAttribute.new(aggregate: "Pizza", name: :size, type: String), ...]
#
module Hecks
  class DomainDiff
    Change = Struct.new(:kind, :context, :aggregate, :details, keyword_init: true)

    def self.call(old_domain, new_domain)
      new(old_domain, new_domain).changes
    end

    def initialize(old_domain, new_domain)
      @old = old_domain
      @new = new_domain
    end

    def changes
      result = []

      @new.contexts.each do |new_ctx|
        old_ctx = @old&.find_context(new_ctx.name)

        new_ctx.aggregates.each do |new_agg|
          old_agg = old_ctx&.aggregates&.find { |a| a.name == new_agg.name }

          if old_agg.nil?
            result << Change.new(
              kind: :add_aggregate,
              context: new_ctx.default? ? nil : new_ctx.name,
              aggregate: new_agg.name,
              details: { attributes: new_agg.attributes, value_objects: new_agg.value_objects }
            )
          else
            result.concat(diff_attributes(new_ctx, old_agg, new_agg))
            result.concat(diff_value_objects(new_ctx, old_agg, new_agg))
          end
        end

        # Removed aggregates
        if old_ctx
          old_ctx.aggregates.each do |old_agg|
            unless new_ctx.aggregates.any? { |a| a.name == old_agg.name }
              result << Change.new(
                kind: :remove_aggregate,
                context: new_ctx.default? ? nil : new_ctx.name,
                aggregate: old_agg.name,
                details: {}
              )
            end
          end
        end
      end

      result
    end

    private

    def diff_attributes(ctx, old_agg, new_agg)
      changes = []
      old_names = old_agg.attributes.map(&:name)
      new_names = new_agg.attributes.map(&:name)

      # Added attributes
      (new_names - old_names).each do |name|
        attr = new_agg.attributes.find { |a| a.name == name }
        changes << Change.new(
          kind: :add_attribute,
          context: ctx.default? ? nil : ctx.name,
          aggregate: new_agg.name,
          details: { name: attr.name, type: attr.type, list: attr.list?, reference: attr.reference? }
        )
      end

      # Removed attributes
      (old_names - new_names).each do |name|
        changes << Change.new(
          kind: :remove_attribute,
          context: ctx.default? ? nil : ctx.name,
          aggregate: new_agg.name,
          details: { name: name }
        )
      end

      changes
    end

    def diff_value_objects(ctx, old_agg, new_agg)
      changes = []
      old_vo_names = old_agg.value_objects.map(&:name)
      new_vo_names = new_agg.value_objects.map(&:name)

      (new_vo_names - old_vo_names).each do |name|
        vo = new_agg.value_objects.find { |v| v.name == name }
        changes << Change.new(
          kind: :add_value_object,
          context: ctx.default? ? nil : ctx.name,
          aggregate: new_agg.name,
          details: { name: vo.name, attributes: vo.attributes }
        )
      end

      (old_vo_names - new_vo_names).each do |name|
        changes << Change.new(
          kind: :remove_value_object,
          context: ctx.default? ? nil : ctx.name,
          aggregate: new_agg.name,
          details: { name: name }
        )
      end

      changes
    end
  end
end
