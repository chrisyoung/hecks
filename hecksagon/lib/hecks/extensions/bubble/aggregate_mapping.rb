# HecksBubble::AggregateMapping
#
# Stores field mappings for a single aggregate within a bubble context.
# Each mapping records a legacy field name, its domain equivalent, and an
# optional transform lambda. Supports forward (legacy -> domain) and
# reverse (domain -> legacy) translation.
#
#   mapping = HecksBubble::AggregateMapping.new(:Pizza)
#   mapping.from_legacy(:pie_name, to: :name)
#   mapping.from_legacy(:pie_desc, to: :description, transform: ->(v) { v.strip })
#
#   mapping.forward(pie_name: "Margherita")   # => { name: "Margherita" }
#   mapping.reverse(name: "Margherita")       # => { pie_name: "Margherita" }
#
module HecksBubble
  class AggregateMapping
    # @return [Symbol] the aggregate name this mapping applies to
    attr_reader :aggregate_name

    # @return [Array<Hash>] the field mapping rules
    attr_reader :rules

    def initialize(aggregate_name)
      @aggregate_name = aggregate_name.to_sym
      @rules = []
    end

    # Declare a field mapping from legacy to domain.
    #
    # @param legacy_field [Symbol] the external/legacy field name
    # @param to [Symbol] the domain field name
    # @param transform [Proc, nil] optional transform applied during forward mapping
    # @return [void]
    def from_legacy(legacy_field, to:, transform: nil)
      @rules << { legacy: legacy_field.to_sym, domain: to.to_sym, transform: transform }
    end

    # Translate legacy data to domain data using declared mappings.
    # Fields not in the mapping pass through unchanged.
    #
    # @param data [Hash] legacy field names and values
    # @return [Hash] domain field names and (optionally transformed) values
    def forward(data)
      result = {}
      mapped_legacy_keys = @rules.map { |r| r[:legacy] }

      data.each do |key, value|
        sym_key = key.to_sym
        rule = @rules.find { |r| r[:legacy] == sym_key }
        if rule
          val = rule[:transform] ? rule[:transform].call(value) : value
          result[rule[:domain]] = val
        else
          result[sym_key] = value unless mapped_legacy_keys.include?(sym_key)
        end
      end

      result
    end

    # Translate domain data back to legacy field names.
    # Transforms are NOT applied in reverse (they may be lossy).
    # Fields not in the mapping pass through unchanged.
    #
    # @param data [Hash] domain field names and values
    # @return [Hash] legacy field names and values
    def reverse(data)
      result = {}
      mapped_domain_keys = @rules.map { |r| r[:domain] }

      data.each do |key, value|
        sym_key = key.to_sym
        rule = @rules.find { |r| r[:domain] == sym_key }
        if rule
          result[rule[:legacy]] = value
        else
          result[sym_key] = value unless mapped_domain_keys.include?(sym_key)
        end
      end

      result
    end
  end
end
