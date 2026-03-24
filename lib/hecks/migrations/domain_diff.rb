# Hecks::Migrations::DomainDiff
#
# Compares two domain snapshots and produces a list of Change objects
# describing what was added, removed, or modified. Adapter-agnostic —
# the changes are structural, not tied to any persistence format.
#
# Used by MigrationStrategies to detect what changed and generate
# appropriate migration files.
#
#   old_domain = Hecks.domain("Pizzas") { ... }
#   new_domain = Hecks.domain("Pizzas") { ... }
#   changes = DomainDiff.call(old_domain, new_domain)
#   # => [Change.new(kind: :add_attribute, aggregate: "Pizza", details: {...}), ...]
#
module Hecks
  module Migrations
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
      old_aggs_by_name = (@old&.aggregates || []).each_with_object({}) { |a, h| h[a.name] = a }

      @new.aggregates.each do |new_agg|
        old_agg = old_aggs_by_name[new_agg.name]

        if old_agg.nil?
          result << Change.new(
            kind: :add_aggregate,
            context: nil,
            aggregate: new_agg.name,
            details: { attributes: new_agg.attributes, value_objects: new_agg.value_objects, validations: new_agg.validations }
          )
        else
          result.concat(diff_attributes(old_agg, new_agg))
          result.concat(diff_value_objects(old_agg, new_agg))
          result.concat(diff_indexes(old_agg, new_agg))
        end
      end

      # Removed aggregates
      new_agg_names = @new.aggregates.map(&:name)
      (@old&.aggregates || []).each do |old_agg|
        unless new_agg_names.include?(old_agg.name)
          result << Change.new(
            kind: :remove_aggregate,
            context: nil,
            aggregate: old_agg.name,
            details: {}
          )
        end
      end

      result
    end

    private

    def diff_attributes(old_agg, new_agg)
      changes = []
      old_names = old_agg.attributes.map(&:name)
      new_names = new_agg.attributes.map(&:name)

      # Added attributes
      (new_names - old_names).each do |name|
        attr = new_agg.attributes.find { |a| a.name == name }
        validation = new_agg.validations.find { |v| v.field == attr.name }
        changes << Change.new(
          kind: :add_attribute,
          context: nil,
          aggregate: new_agg.name,
          details: { name: attr.name, type: attr.type, list: attr.list?, reference: attr.reference?,
                     default: attr.default, presence: validation&.presence?, uniqueness: validation&.uniqueness? }
        )
      end

      # Removed attributes
      (old_names - new_names).each do |name|
        changes << Change.new(
          kind: :remove_attribute,
          context: nil,
          aggregate: new_agg.name,
          details: { name: name }
        )
      end

      changes
    end

    def diff_value_objects(old_agg, new_agg)
      changes = []
      old_vo_names = old_agg.value_objects.map(&:name)
      new_vo_names = new_agg.value_objects.map(&:name)

      (new_vo_names - old_vo_names).each do |name|
        vo = new_agg.value_objects.find { |v| v.name == name }
        changes << Change.new(
          kind: :add_value_object,
          context: nil,
          aggregate: new_agg.name,
          details: { name: vo.name, attributes: vo.attributes }
        )
      end

      (old_vo_names - new_vo_names).each do |name|
        changes << Change.new(
          kind: :remove_value_object,
          context: nil,
          aggregate: new_agg.name,
          details: { name: name }
        )
      end

      changes
    end

    def diff_indexes(old_agg, new_agg)
      changes = []
      old_idx = (old_agg.indexes || []).map { |i| i[:fields] }
      new_idx = (new_agg.indexes || []).map { |i| i[:fields] }

      (new_agg.indexes || []).each do |idx|
        unless old_idx.include?(idx[:fields])
          changes << Change.new(
            kind: :add_index,
            context: nil,
            aggregate: new_agg.name,
            details: idx
          )
        end
      end

      (old_agg.indexes || []).each do |idx|
        unless new_idx.include?(idx[:fields])
          changes << Change.new(
            kind: :remove_index,
            context: nil,
            aggregate: new_agg.name,
            details: idx
          )
        end
      end

      changes
    end
    end
  end
end
