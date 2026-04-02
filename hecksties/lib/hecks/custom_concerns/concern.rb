# Hecks::CustomConcerns::Concern
#
# Immutable value object representing a user-defined governance concern.
# A concern has a name, description, required extensions, and validation
# rules. Custom concerns compose extensions and add domain-specific
# governance checks.
#
#   concern = Concern.new(
#     name: :hipaa_compliance,
#     description: "HIPAA compliance for healthcare data",
#     required_extensions: [:pii, :audit, :auth],
#     rules: [Rule.new("PII must be hidden") { |agg| ... }]
#   )
#   concern.name                # => :hipaa_compliance
#   concern.required_extensions # => [:pii, :audit, :auth]
#
module Hecks
  module CustomConcerns
    class Concern
      # @return [Symbol] the concern name
      attr_reader :name

      # @return [String] human-readable description
      attr_reader :description

      # @return [Array<Symbol>] extensions this concern requires
      attr_reader :required_extensions

      # @return [Array<Rule>] validation rules for this concern
      attr_reader :rules

      # @param name [Symbol] concern identifier
      # @param description [String] what this concern enforces
      # @param required_extensions [Array<Symbol>] extensions that must be enabled
      # @param rules [Array<Rule>] validation rules
      def initialize(name:, description: "", required_extensions: [], rules: [])
        @name = name.to_sym
        @description = description
        @required_extensions = required_extensions.map(&:to_sym).freeze
        @rules = rules.freeze
      end
    end
  end
end
