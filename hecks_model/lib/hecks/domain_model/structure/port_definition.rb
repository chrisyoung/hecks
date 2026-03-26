# Hecks::DomainModel::Structure::PortDefinition
#
# Represents a named port that defines which methods are accessible
# through a particular access level (e.g., :guest, :admin).
#
# A port is attached to an aggregate and contains a list of allowed
# method names. Used by the Application layer to enforce access control
# -- when a request comes through a specific port, only the methods
# listed in that port's +allowed_methods+ can be invoked.
#
# Ports implement the Ports & Adapters (hexagonal) pattern: each port
# is a named boundary with a restricted interface into the domain.
#
#   port = PortDefinition.new(name: :guest, allowed_methods: [:find, :all, :where])
#   port.allows?(:find)    # => true
#   port.allows?(:create)  # => false
#
module Hecks
  module DomainModel
    module Structure
    class PortDefinition
      # @return [Symbol] the port name identifying the access level or role (e.g., :guest, :admin, :api)
      attr_reader :name

      # @return [Array<Symbol>] the method names that are permitted through this port.
      #   Methods not in this list will be rejected at the Application layer.
      attr_reader :allowed_methods

      # Creates a new PortDefinition.
      #
      # @param name [Symbol, String] the name of this port/access level (e.g., :guest, :admin)
      # @param allowed_methods [Array<Symbol, String>] the method names allowed through this port.
      #   Each element is converted to a Symbol via +to_sym+.
      #
      # @return [PortDefinition] a new PortDefinition instance
      def initialize(name:, allowed_methods: [])
        @name = name
        @allowed_methods = allowed_methods.map(&:to_sym)
      end

      # Checks whether a given method is allowed through this port.
      #
      # @param method_name [Symbol, String] the method name to check. Converted to Symbol for comparison.
      #
      # @return [Boolean] true if the method is in the allowed list, false otherwise
      def allows?(method_name)
        allowed_methods.include?(method_name.to_sym)
      end
    end
    end
  end
end
