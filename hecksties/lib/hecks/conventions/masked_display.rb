# = Hecks::Conventions::MaskedDisplay
#
# Display masking convention for sensitive attributes. Attributes tagged
# with `masked: true` in the domain DSL show only their last 4 characters
# in all display contexts (web explorer, introspection, CLI).
#
# Supports both DSL-level masking (`attribute :ssn, String, masked: true`)
# and hecksagon capability tagging (`capability.ssn.masked`).
#
#   Hecks::Conventions::MaskedDisplay.mask("123-45-6789")
#   # => "***-**-6789"
#
#   Hecks::Conventions::MaskedDisplay.masked_attributes(hecksagon, "Customer")
#   # => ["ssn", "account_number"]
#
module Hecks::Conventions
  module MaskedDisplay
    # Mask a value for display, preserving only the last 4 characters.
    # All preceding characters are replaced with asterisks, preserving
    # the original character positions (hyphens, spaces stay as-is).
    #
    # @param value [String, nil] the value to mask
    # @return [String, nil] the masked string, or nil if value was nil
    def self.mask(value)
      return nil if value.nil?
      s = value.to_s
      return s if s.empty?
      return "****" if s.length <= 4

      visible = s[-4..]
      hidden = s[0...-4].gsub(/[^\s\-\/.]/, "*")
      "#{hidden}#{visible}"
    end

    # Return attribute names tagged as masked on a given aggregate.
    # Checks both DSL-level `masked: true` flags and hecksagon capability
    # tags (`:masked`).
    #
    # @param aggregate [Aggregate] the aggregate IR
    # @param hecksagon [Hecksagon, nil] optional hecksagon IR for capability tags
    # @param aggregate_name [String] the aggregate name for capability lookup
    # @return [Array<Symbol>] names of masked attributes
    def self.masked_attributes(aggregate, hecksagon: nil, aggregate_name: nil)
      dsl_masked = aggregate.attributes.select(&:masked?).map(&:name)

      cap_masked = []
      if hecksagon && aggregate_name
        tags = hecksagon.aggregate_capabilities[aggregate_name] || []
        cap_masked = tags.select { |t| t[:tag] == :masked }
                        .map { |t| t[:attribute].to_sym }
      end

      (dsl_masked + cap_masked).uniq
    end

    # Check if a specific attribute is masked, either via DSL flag or
    # hecksagon capability tag.
    #
    # @param attr [Attribute] the attribute to check
    # @param hecksagon [Hecksagon, nil] optional hecksagon IR
    # @param aggregate_name [String, nil] the aggregate name
    # @return [Boolean]
    def self.masked?(attr, hecksagon: nil, aggregate_name: nil)
      return true if attr.masked?
      return false unless hecksagon && aggregate_name

      tags = hecksagon.aggregate_capabilities[aggregate_name] || []
      tags.any? { |t| t[:tag] == :masked && t[:attribute].to_s == attr.name.to_s }
    end
  end
end
