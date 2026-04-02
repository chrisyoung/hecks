module Hecksagon
  module Structure

    # Hecksagon::Structure::Hecksagon
    #
    # Intermediate representation of the hexagonal architecture wiring for a
    # domain. Holds gates (access control), adapter configuration, extensions,
    # cross-domain subscriptions, and tenancy strategy.
    #
    # Built by the Hecksagon DSL builder, consumed by the runtime boot sequence.
    #
    #   hex = Hecksagon.new(
    #     name: "Pizzas",
    #     gates: [GateDefinition.new(aggregate: "Pizza", role: :admin, allowed_methods: [:find])],
    #     adapter: { type: :sqlite, database: "app.db" },
    #     extensions: [{ name: :audit }],
    #     subscriptions: ["Billing"],
    #     tenancy: :row
    #   )
    #
    class Hecksagon
      attr_reader :name, :gates, :adapter, :extensions, :subscriptions, :tenancy

      def initialize(name:, gates: [], adapter: nil, extensions: [], subscriptions: [], tenancy: nil)
        @name = name
        @gates = gates
        @adapter = adapter
        @extensions = extensions
        @subscriptions = subscriptions
        @tenancy = tenancy
      end

      # Returns gates for a specific aggregate.
      def gates_for(aggregate_name)
        @gates.select { |g| g.aggregate == aggregate_name.to_s }
      end

      # Returns the gate for a specific aggregate + role combination.
      def gate_for(aggregate_name, role)
        @gates.find { |g| g.aggregate == aggregate_name.to_s && g.role == role.to_sym }
      end

      # Returns encrypted attribute names for a given aggregate, queried from
      # the domain IR. Returns an empty array if the domain is not set or the
      # aggregate has no encrypted attributes.
      #
      # @param aggregate_name [String] the aggregate name
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR
      # @return [Array<Symbol>] names of encrypted attributes
      def encrypted_attributes(aggregate_name, domain:)
        agg = domain.aggregates.find { |a| a.name == aggregate_name.to_s }
        return [] unless agg
        agg.attributes.select(&:encrypted?).map(&:name)
      end
    end
  end
end
