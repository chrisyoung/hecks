module Hecks
  module DSL

    # Hecks::DSL::PortBuilder
    #
    # DSL builder for port definitions inside an aggregate block.
    # Collects allowed method names and builds a PortDefinition.
    #
    #   port :guest do
    #     allow :find, :all, :where
    #   end
    #
    # Builds a DomainModel::Structure::PortDefinition from access declarations.
    #
    # PortBuilder defines a named access port that restricts which repository
    # and command operations are available to a given role. Each port has a name
    # (typically a role like +:guest+ or +:admin+) and a whitelist of allowed
    # method symbols. At runtime, port-based access control checks incoming
    # operations against this whitelist.
    #
    # Used inside +AggregateBuilder#port+ blocks.
    class PortBuilder
      # Initialize a new port builder with the given port/role name.
      #
      # @param name [Symbol] the port or role name (e.g. :guest, :admin, :api)
      def initialize(name)
        @name = name
        @allowed = []
      end

      # Declare one or more methods as allowed through this port.
      #
      # Method names are converted to symbols and accumulated. Can be called
      # multiple times to add more allowed methods.
      #
      # @param methods [Array<Symbol, String>] method names to allow
      # @return [void]
      #
      # @example
      #   allow :find, :all, :where
      def allow(*methods)
        @allowed.concat(methods.map(&:to_sym))
      end

      # Build and return the DomainModel::Structure::PortDefinition IR object.
      #
      # @return [DomainModel::Structure::PortDefinition] the port definition with
      #   the accumulated allowed methods
      def build
        DomainModel::Structure::PortDefinition.new(name: @name, allowed_methods: @allowed)
      end
    end
  end
end
