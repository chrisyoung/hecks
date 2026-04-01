module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::PersistenceMetadata
    #
    # Holds persistence-specific concerns for an aggregate: database indexes,
    # identity fields (natural keys), and future storage hints. Separates
    # persistence details from the core Aggregate IR so generators and the
    # migration system have a single place to look for storage configuration.
    #
    # Built by AggregateBuilder and attached to the Aggregate via
    # +aggregate.persistence_metadata+.
    #
    #   meta = PersistenceMetadata.new(
    #     indexes: [{ fields: [:email], unique: true }],
    #     identity_fields: [:team, :start_date]
    #   )
    #   meta.indexes          # => [{ fields: [:email], unique: true }]
    #   meta.identity_fields  # => [:team, :start_date]
    #
    class PersistenceMetadata
      # @return [Array<Hash>] database index definitions with :fields and :unique keys
      attr_reader :indexes

      # @return [Array<Symbol>, nil] natural key fields for secondary identity lookup
      attr_reader :identity_fields

      # Creates a new PersistenceMetadata.
      #
      # @param indexes [Array<Hash>] index definitions, each with :fields (Array<Symbol>)
      #   and :unique (Boolean)
      # @param identity_fields [Array<Symbol>, nil] natural key fields
      # @return [PersistenceMetadata]
      def initialize(indexes: [], identity_fields: nil)
        @indexes = indexes
        @identity_fields = identity_fields
      end
    end
    end
  end
end
