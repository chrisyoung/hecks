module Hecks
  module Persistence
    # Hecks::Persistence::ReferenceMethods
    #
    # Binds reference resolution methods onto aggregate classes during application
    # boot. For each reference declared on the aggregate, defines a getter that
    # hydrates the referenced aggregate by looking up its stored ID, and a writer
    # that accepts either an object or raw ID.
    #
    # The domain layer works with live objects — IDs are a persistence concern.
    #
    # == Usage
    #
    #   ReferenceMethods.bind(PlayerClass, player_aggregate)
    #   player = Player.find(1)
    #   player.team       # => Team instance (hydrated from stored team_id)
    #
    module ReferenceMethods
      # Defines reference resolution methods on the given aggregate class.
      #
      # For each reference on the aggregate, defines a getter that resolves the
      # referenced aggregate by calling find on the target class, and a writer
      # that stores the reference.
      #
      # @param klass [Class] the aggregate class to augment
      # @param aggregate [Hecks::DomainModel::Structure::Aggregate] the domain model metadata
      # @return [void]
      def self.bind(klass, aggregate)
        (aggregate.references || []).each do |ref|
          method_name = ref.name
          id_column = :"#{ref.name}_id"
          ref_type = ref.type.to_s

          klass.define_method(method_name) do
            ref_id = instance_variable_get(:"@#{id_column}") || send(id_column) rescue nil
            return nil unless ref_id
            begin; Object.const_get(ref_type).find(ref_id); rescue NameError; nil; end
          end
        end
      end
      end
  end
end
