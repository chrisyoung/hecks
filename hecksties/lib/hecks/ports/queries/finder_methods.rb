module Hecks
  module Querying
    # Hecks::Querying::FinderMethods
    #
    # Binds custom finder methods onto aggregate classes. Finders are declared
    # in the domain DSL and represent named repository lookup methods that
    # filter by equality on one or more attributes. Each finder becomes a
    # singleton method on the aggregate class that delegates to the
    # repository's finder implementation.
    #
    # == Usage
    #
    #   # In the domain DSL:
    #   finder :by_email, :email
    #   finder :by_status_and_priority, :status, :priority
    #
    #   # After binding:
    #   FinderMethods.bind(UserClass, user_aggregate)
    #   User.by_email("alice@example.com")         # => [User, ...]
    #   User.by_status_and_priority("active", "high") # => [User, ...]
    #
    module FinderMethods
      # Binds all finders from the aggregate definition as class methods.
      #
      # For each finder, defines a singleton method on the aggregate class
      # that delegates to the repository's method of the same name.
      #
      # @param klass [Class] the aggregate class to receive finder methods;
      #   must have +@__hecks_repo__+ set (done by AdHocQueries.bind)
      # @param aggregate [Hecks::DomainModel::Structure::Aggregate] the aggregate
      #   definition containing finder metadata
      # @return [void]
      def self.bind(klass, aggregate)
        aggregate.finders.each do |finder|
          repo = klass.instance_variable_get(:@__hecks_repo__)
          finder_name = finder.name
          klass.define_singleton_method(finder_name) do |*args|
            repo.send(finder_name, *args)
          end
        end
      end
    end
  end
end
