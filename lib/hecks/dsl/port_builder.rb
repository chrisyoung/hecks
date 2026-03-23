# Hecks::DSL::PortBuilder
#
# DSL builder for port definitions inside an aggregate block.
# Collects allowed method names and builds a PortDefinition.
#
#   port :guest do
#     allow :find, :all, :where
#   end
#
module Hecks
  module DSL
    class PortBuilder
      def initialize(name)
        @name = name
        @allowed = []
      end

      def allow(*methods)
        @allowed.concat(methods.map(&:to_sym))
      end

      def build
        DomainModel::Structure::PortDefinition.new(name: @name, allowed_methods: @allowed)
      end
    end
  end
end
