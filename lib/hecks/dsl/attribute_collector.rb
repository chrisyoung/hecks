module Hecks
  module DSL
    module AttributeCollector
      def attribute(name, type, **options)
        list = type.is_a?(Hash) && type[:list]
        ref = type.is_a?(Hash) && type[:reference]
        actual_type = type.is_a?(Hash) ? type.values.first : type

        @attributes << DomainModel::Attribute.new(
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
