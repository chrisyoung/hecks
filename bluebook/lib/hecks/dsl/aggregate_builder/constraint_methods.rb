# Hecks::DSL::AggregateBuilder::ConstraintMethods
#
# Validation, invariant, and port DSL methods extracted from AggregateBuilder.
#
module Hecks
  module DSL
    class AggregateBuilder
      module ConstraintMethods
        # Add a field-level validation rule.
        #
        # @param field [Symbol] the attribute name to validate
        # @param rules [Hash] validation rules (e.g. +{ presence: true }+)
        # @return [void]
        def validation(field, rules)
          @validations << DomainModel::Structure::Validation.new(field: field, rules: rules)
        end

        # Define an aggregate-level invariant.
        #
        # @param message [String] human-readable invariant description
        # @yield block that returns true when the invariant holds
        # @return [void]
        def invariant(message, &block)
          @invariants << DomainModel::Structure::Invariant.new(message: message, block: block)
        end

        # Define an access port restricting allowed operations for a role.
        #
        # @param name [Symbol] the role name (e.g. :guest, :admin)
        # @param methods [Array<Symbol>, nil] shorthand list of allowed methods
        # @yield block evaluated in PortBuilder context
        # @return [void]
        def port(name, methods = nil, &block)
          port_builder = PortBuilder.new(name)
          if methods
            methods.each { |m| port_builder.allow(m) }
          end
          port_builder.instance_eval(&block) if block
          @ports[name] = port_builder.build
        end
      end
    end
  end
end
