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
      TYPE_MAP = {
        string: String, str: String,
        integer: Integer, int: Integer,
        float: Float,
        boolean: TrueClass, bool: TrueClass,
        symbol: Symbol, sym: Symbol,
        array: Array,
        hash: Hash,
      }.freeze

      def attribute(name, type = String, **options)
        type = resolve_type(type)
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

      private

      def resolve_type(type)
        case type
        when Symbol then TYPE_MAP.fetch(type) { type }
        when String then TYPE_MAP.fetch(type.downcase.to_sym) { type }
        else type
        end
      end
    end
  end
end
