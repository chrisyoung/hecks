# Hecks::Persistence::ReferenceMethods
#
# Binds reference resolution methods onto aggregate classes during application boot.
# For each attribute marked as a reference (+reference_to+), defines a convenience
# method that resolves the referenced aggregate by looking up its ID.
#
# For example, if an Order aggregate has a +pizza_id+ attribute declared as
# +reference_to: "Pizza"+, this module defines an +order.pizza+ method that
# calls +Pizza.find(order.pizza_id)+.
#
# Reference resolution is lazy -- the lookup happens each time the method is called,
# not at load time. If the referenced class cannot be found (NameError) or the ID
# is nil, the method returns nil.
#
# == Usage
#
#   ReferenceMethods.bind(OrderClass, order_aggregate)
#   order = Order.find(1)
#   order.pizza      # => Pizza instance (calls Pizza.find(order.pizza_id))
#   order.pizza_id   # => the raw ID value (original attribute)
#
module Hecks
  module Persistence
    module ReferenceMethods
      # Defines reference resolution methods on the given aggregate class.
      #
      # Iterates over all reference attributes on the aggregate and defines an
      # instance method named after the referenced type (stripping the +_id+ suffix).
      # Each method calls +find+ on the referenced aggregate class.
      #
      # @param klass [Class] the aggregate class to augment (e.g., Order)
      # @param aggregate [Hecks::DomainModel::Aggregate] the domain model metadata
      #   describing this aggregate's attributes; only attributes where +reference?+
      #   returns true are processed
      # @return [void]
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
