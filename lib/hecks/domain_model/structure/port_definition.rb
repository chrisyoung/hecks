# Hecks::DomainModel::PortDefinition
#
# Represents a named port that defines which methods are accessible
# through a particular access level (e.g., :guest, :admin).
#
# A port is attached to an aggregate and contains a list of allowed
# method names. Used by the Application layer to enforce access control.
#
#   port = PortDefinition.new(name: :guest, allowed_methods: [:find, :all, :where])
#   port.allows?(:find)    # => true
#   port.allows?(:create)  # => false
#
module Hecks
  module DomainModel
    module Structure
    class PortDefinition
      attr_reader :name, :allowed_methods

      def initialize(name:, allowed_methods: [])
        @name = name
        @allowed_methods = allowed_methods.map(&:to_sym)
      end

      def allows?(method_name)
        allowed_methods.include?(method_name.to_sym)
      end
    end
    end
  end
end
