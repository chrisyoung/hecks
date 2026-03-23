# Hecks::Services::Querying::ScopeMethods
#
# Binds named scope methods onto aggregate classes. Scopes are defined
# in the DSL and wrap QueryBuilder.where calls.
#
#   ScopeMethods.bind(PizzaClass, pizza_aggregate)
#   Pizza.classics  # => QueryBuilder result
#
module Hecks
  module Services
    module Querying
      module ScopeMethods
        def self.bind(klass, aggregate)
          aggregate.scopes.each do |scope|
            if scope.callable?
              klass.define_singleton_method(scope.name) do |*args|
                conditions = scope.conditions.call(*args)
                Querying::QueryBuilder.new(instance_variable_get(:@__hecks_repo__)).where(**conditions)
              end
            else
              klass.define_singleton_method(scope.name) do
                Querying::QueryBuilder.new(instance_variable_get(:@__hecks_repo__)).where(**scope.conditions)
              end
            end
          end
        end
      end
    end
  end
end
