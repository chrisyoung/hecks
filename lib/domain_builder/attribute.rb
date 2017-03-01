module Hecks
  class DomainBuilder
    class Attribute
      attr_writer :type
      def initialize(string)
        @string = string
      end

      def list?
        @string.include?("[")
      end

      def name
        @string.split(":").first
      end

      def type
        return @type if @type
        @string.split(":").last.delete("[").delete("]").camelize
      end

      def domain_module
        return unless @string.include?("::")
        @string.split("::").first.split(":").last.camelize
      end

      def copy(new_values={})
        result = self.class.new(@string)
        result.type = new_values[:type] if new_values[:type]
        result
      end

      def ==(other)
        return false if other.name != name
        return false if other.type != type
        return false if other.domain_module != domain_module
        return true
      end
    end
  end
end
