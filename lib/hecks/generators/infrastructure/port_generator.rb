# Hecks::Generators::PortGenerator
#
# Generates repository port interfaces (modules with NotImplementedError stubs).
# Consuming apps include the port and implement the methods.
#
#   gen = PortGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Ports\n    module PizzaRepository\n  ..."
#
#   # With context:
#   gen = PortGenerator.new(agg, domain_module: "PizzasDomain", context_module: "Ordering")
#   gen.generate  # => "...module Ports\n  module Ordering\n    module OrderRepository\n  ..."
#
module Hecks
  module Generators
    module Infrastructure
    class PortGenerator
      include ContextAware

      def initialize(aggregate, domain_module:, context_module: nil)
        @aggregate = aggregate
        @domain_module = domain_module
        @context_module = context_module
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Ports"
        if @context_module
          lines << "    module #{@context_module}"
          lines << "      module #{@aggregate.name}Repository"
          lines << "        def find(id)"
          lines << "          raise NotImplementedError, \"\#{self.class}#find not implemented\""
          lines << "        end"
          lines << ""
          lines << "        def save(#{Hecks::Utils.underscore(@aggregate.name)})"
          lines << "          raise NotImplementedError, \"\#{self.class}#save not implemented\""
          lines << "        end"
          lines << ""
          lines << "        def delete(id)"
          lines << "          raise NotImplementedError, \"\#{self.class}#delete not implemented\""
          lines << "        end"
          lines << "      end"
          lines << "    end"
        else
          lines << "    module #{@aggregate.name}Repository"
          lines << "      def find(id)"
          lines << "        raise NotImplementedError, \"\#{self.class}#find not implemented\""
          lines << "      end"
          lines << ""
          lines << "      def save(#{Hecks::Utils.underscore(@aggregate.name)})"
          lines << "        raise NotImplementedError, \"\#{self.class}#save not implemented\""
          lines << "      end"
          lines << ""
          lines << "      def delete(id)"
          lines << "        raise NotImplementedError, \"\#{self.class}#delete not implemented\""
          lines << "      end"
          lines << "    end"
        end
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

    end
    end
  end
end
