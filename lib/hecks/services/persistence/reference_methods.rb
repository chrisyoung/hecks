# Hecks::Persistence::ReferenceMethods
#
# Binds reference resolution methods onto aggregate classes. For each
# reference_to attribute (e.g. pizza_id), defines a method that resolves
# the referenced aggregate (e.g. order.pizza).
#
#   ReferenceMethods.bind(OrderClass, order_aggregate)
#   order.pizza  # => resolves Pizza.find(order.pizza_id)
#
module Hecks
  module Persistence
    module ReferenceMethods
      def self.bind(klass, aggregate)
        aggregate.attributes.select(&:reference?).each do |ref_attr|
          method_name = ref_attr.name.to_s.sub(/_id$/, "").to_sym
          ref_type = ref_attr.type.to_s

          klass.define_method(method_name) do
            ref_id = send(ref_attr.name)
            return nil unless ref_id
            begin; Object.const_get(ref_type).find(ref_id); rescue NameError; nil; end
          end
        end
      end
      end
  end
end
