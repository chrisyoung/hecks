# Hecks::CustomConcerns::ConcernBuilder
#
# DSL builder for defining custom concerns. Parses the block passed to
# `Hecks.concern` and builds a Concern value object with name, description,
# required extensions, and validation rules.
#
#   builder = ConcernBuilder.new(:hipaa_compliance)
#   builder.instance_eval do
#     description "HIPAA compliance for healthcare data"
#     requires_extension :pii
#     requires_extension :audit
#     rule "All PII fields must be encrypted" do |aggregate|
#       aggregate.attributes.select(&:pii?).all? { |a| !a.visible? }
#     end
#   end
#   concern = builder.build
#
module Hecks
  module CustomConcerns
    class ConcernBuilder
      def initialize(name)
        @name = name.to_sym
        @description = ""
        @required_extensions = []
        @rules = []
      end

      # Set the concern description.
      #
      # @param text [String] human-readable description
      # @return [void]
      def description(text)
        @description = text
      end

      # Declare a required extension for this concern.
      #
      # @param name [Symbol] extension name (e.g., :pii, :audit, :auth)
      # @return [void]
      def requires_extension(name)
        @required_extensions << name.to_sym
      end

      # Define a validation rule for this concern.
      #
      # @param name [String] human-readable rule description
      # @yield [aggregate] block that validates an aggregate
      # @yieldparam aggregate [Hecks::DomainModel::Structure::Aggregate]
      # @yieldreturn [Boolean] true if the rule passes
      # @return [void]
      def rule(name, &block)
        @rules << Rule.new(name, &block)
      end

      # Build and return the Concern value object.
      #
      # @return [Concern]
      def build
        Concern.new(
          name: @name,
          description: @description,
          required_extensions: @required_extensions,
          rules: @rules
        )
      end
    end
  end
end
