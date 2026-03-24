# Hecks::Services::Persistence::CollectionMethods
#
# Binds collection proxy accessors onto aggregate classes. For each
# list attribute with a value object, defines an instance method that
# returns a CollectionProxy for persistence-aware mutations.
#
#   CollectionMethods.bind(PizzaClass, pizza_aggregate, repo)
#   pizza.toppings.create(name: "Mozzarella", amount: 2)
#
module Hecks
  module Services
    module Persistence
      module CollectionMethods
      def self.bind(klass, aggregate, repo)
        aggregate.attributes.select(&:list?).each do |list_attr|
          vo = aggregate.value_objects.find { |v| v.name == list_attr.type.to_s }
          vo ||= aggregate.entities.find { |e| e.name == list_attr.type.to_s }
          next unless vo
          attr_name = list_attr.name
          vo_class = begin; klass.const_get(vo.name); rescue NameError; nil; end
          next unless vo_class
          repo_ref = repo

          klass.define_method(attr_name) do
            items = instance_variable_get(:"@#{attr_name}") || []
            Persistence::CollectionProxy.new(items: items, owner: self, attr_name: attr_name,
                                value_object_class: vo_class, repo: repo_ref)
          end
        end
      end
      end
    end
  end
end
