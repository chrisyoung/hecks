# Hecks::Generators::MemoryAdapterGenerator
#
# Generates in-memory repository implementations that store aggregates in a
# hash. Every aggregate gets one by default — zero setup needed.
#
#   gen = MemoryAdapterGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Adapters\n    class PizzaMemoryRepository\n  ..."
#
#   # With context:
#   gen = MemoryAdapterGenerator.new(agg, domain_module: "PizzasDomain", context_module: "Ordering")
#   gen.generate  # => "...module Adapters\n  module Ordering\n    class OrderMemoryRepository\n  ..."
#
module Hecks
  module Generators
    class MemoryAdapterGenerator
      include ContextAware

      def initialize(aggregate, domain_module:, context_module: nil)
        @aggregate = aggregate
        @domain_module = domain_module
        @context_module = context_module
      end

      def generate
        port_path = if @context_module
                      "Ports::#{@context_module}::#{@aggregate.name}Repository"
                    else
                      "Ports::#{@aggregate.name}Repository"
                    end

        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Adapters"
        if @context_module
          lines << "    module #{@context_module}"
          lines << "      class #{@aggregate.name}MemoryRepository"
          lines << "        include #{port_path}"
          lines << ""
          lines << "        def initialize"
          lines << "          @store = {}"
          lines << "        end"
          lines << ""
          lines << "        def find(id)"
          lines << "          @store[id]"
          lines << "        end"
          lines << ""
          lines << "        def save(#{Hecks::Utils.underscore(@aggregate.name)})"
          lines << "          @store[#{Hecks::Utils.underscore(@aggregate.name)}.id] = #{Hecks::Utils.underscore(@aggregate.name)}"
          lines << "        end"
          lines << ""
          lines << "        def delete(id)"
          lines << "          @store.delete(id)"
          lines << "        end"
          lines << ""
          lines << "        def all"
          lines << "          @store.values"
          lines << "        end"
          lines << ""
          lines << "        def count"
          lines << "          @store.size"
          lines << "        end"
          lines << ""
          lines << "        def clear"
          lines << "          @store.clear"
          lines << "        end"
          lines << "      end"
          lines << "    end"
        else
          lines << "    class #{@aggregate.name}MemoryRepository"
          lines << "      include #{port_path}"
          lines << ""
          lines << "      def initialize"
          lines << "        @store = {}"
          lines << "      end"
          lines << ""
          lines << "      def find(id)"
          lines << "        @store[id]"
          lines << "      end"
          lines << ""
          lines << "      def save(#{Hecks::Utils.underscore(@aggregate.name)})"
          lines << "        @store[#{Hecks::Utils.underscore(@aggregate.name)}.id] = #{Hecks::Utils.underscore(@aggregate.name)}"
          lines << "      end"
          lines << ""
          lines << "      def delete(id)"
          lines << "        @store.delete(id)"
          lines << "      end"
          lines << ""
          lines << "      def all"
          lines << "        @store.values"
          lines << "      end"
          lines << ""
          lines << "      def count"
          lines << "        @store.size"
          lines << "      end"
          lines << ""
          lines << "      def clear"
          lines << "        @store.clear"
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
