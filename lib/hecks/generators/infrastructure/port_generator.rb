# Hecks::Generators::Infrastructure::PortGenerator
#
# Generates repository port interfaces (modules with NotImplementedError stubs).
# Consuming apps include the port and implement the methods.
#
#   gen = PortGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Ports\n    module PizzaRepository\n  ..."
#
module Hecks
  module Generators
    module Infrastructure
    class PortGenerator

      def initialize(aggregate, domain_module:)
        @aggregate = aggregate
        @domain_module = domain_module
        @safe_name = Hecks::Utils.sanitize_constant(@aggregate.name)
      end

      def generate
        snake = Hecks::Utils.underscore(@safe_name)
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Ports"
        lines << "    module #{@safe_name}Repository"
        lines << "      def find(id)"
        lines << "        raise NotImplementedError, \"\#{self.class}#find not implemented\""
        lines << "      end"
        lines << ""
        lines << "      def save(#{snake})"
        lines << "        raise NotImplementedError, \"\#{self.class}#save not implemented\""
        lines << "      end"
        lines << ""
        lines << "      def delete(id)"
        lines << "        raise NotImplementedError, \"\#{self.class}#delete not implemented\""
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

    end
    end
  end
end
