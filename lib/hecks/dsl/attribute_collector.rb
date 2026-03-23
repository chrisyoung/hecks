# Hecks::DSL::AttributeCollector
#
# Shared mixin for DSL builders that collect attributes. Provides the
# `attribute`, `list_of`, and `reference_to` DSL methods. Included by
# AggregateBuilder, CommandBuilder, ValueObjectBuilder, and DomainBuilder.
#
#   attribute :name, String
#   attribute :toppings, list_of("Topping")
#   attribute :order, reference_to("Order")
#
module Hecks
  module DSL
    module AttributeCollector
      def attribute(name, type, **options)
        list = type.is_a?(Hash) && type[:list]
        ref = type.is_a?(Hash) && type[:reference]
        actual_type = type.is_a?(Hash) ? type.values.first : type

        @attributes << DomainModel::Structure::Attribute.new(
          name: name,
          type: actual_type,
          list: !!list,
          reference: !!ref,
          **options
        )
      end

      def list_of(type)
        { list: type }
      end

      def reference_to(type)
        { reference: type }
      end
    end
  end
end
