# Hecks::Runtime::FinderMethods
#
# Binds custom finder methods (declared via +finder+ in the DSL) onto
# repository instances at runtime. Each finder becomes a +find_by_<name>+
# method that scans the repository for a matching aggregate.
#
# Usage:
#   FinderMethods.bind(aggregate_ir, repository)
#   repository.find_by_email("alice@example.com")
#
module Hecks
  class Runtime
    module FinderMethods
      # Bind finder methods from the aggregate IR onto the repository.
      #
      # @param aggregate [Hecks::DomainModel::Structure::Aggregate]
      # @param repository [Object] the repository instance
      # @return [void]
      def self.bind(aggregate, repository)
        return unless aggregate.respond_to?(:finders)

        aggregate.finders.each do |finder|
          attr_name = finder.attribute
          method_name = :"find_by_#{finder.name}"

          repository.define_singleton_method(method_name) do |value|
            all.find { |obj| obj.respond_to?(attr_name) && obj.send(attr_name) == value }
          end
        end
      end
    end
  end
end
