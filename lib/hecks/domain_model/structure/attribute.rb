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
#   json_attr = Attribute.new(name: :points, type: JSON)
#   json_attr.json?  # => true
#
module Hecks
  module DomainModel
    module Structure
    class Attribute
      attr_reader :name, :type, :default

      def initialize(name:, type:, default: nil, list: false, reference: false, pii: false)
        @name = name.to_sym
        @type = type
        @default = default
        @list = list
        @reference = reference
        @pii = pii
      end

      def list?
        @list
      end

      def reference?
        @reference
      end

      def pii?
        @pii
      end

      def json?
        type == JSON
      end

      def ruby_type
        if reference?
          "String"
        elsif list?
          "Array"
        elsif json?
          "JSON"
        else
          type.to_s
        end
      end
    end
    end
  end
end
