# Hecks::DomainModel::Structure::Attribute
#
# Represents a typed attribute on an aggregate, value object, command, or event.
# Supports scalar types (String, Integer), list types, and cross-aggregate
# references.
#
# The most granular building block in the DomainModel IR. Used by every builder
# and every generator.
#
#   attr = Attribute.new(name: :name, type: String)
#   attr.ruby_type     # => "String"
#
#   list_attr = Attribute.new(name: :toppings, type: "Topping", list: true)
#   list_attr.list?    # => true
#   list_attr.ruby_type  # => "Array"
#
#   ref_attr = Attribute.new(name: :order_id, type: "Order", reference: true)
#   ref_attr.reference?  # => true
#
module Hecks
  module DomainModel
    module Structure
    class Attribute
      attr_reader :name, :type, :default

      def initialize(name:, type:, default: nil, list: false, reference: false)
        @name = name.to_sym
        @type = type
        @default = default
        @list = list
        @reference = reference
      end

      def list?
        @list
      end

      def reference?
        @reference
      end

      def ruby_type
        if reference?
          "String"
        elsif list?
          "Array"
        else
          type.to_s
        end
      end
    end
    end
  end
end
