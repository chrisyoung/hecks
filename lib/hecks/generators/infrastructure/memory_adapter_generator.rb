# Hecks::Generators::Infrastructure::MemoryAdapterGenerator
#
# Generates in-memory repository implementations that store aggregates in a
# hash. Every aggregate gets one by default — zero setup needed. Includes a
# query method for adapter-driven filtering, sorting, and pagination.
#
#   gen = MemoryAdapterGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  module Adapters\n    class PizzaMemoryRepository\n  ..."
#
module Hecks
  module Generators
    module Infrastructure
    class MemoryAdapterGenerator

      def initialize(aggregate, domain_module:)
        @aggregate = aggregate
        @domain_module = domain_module
        @safe_name = Hecks::Utils.sanitize_constant(@aggregate.name)
      end

      def generate
        snake = Hecks::Utils.underscore(@safe_name)
        port_path = "Ports::#{@safe_name}Repository"

        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Adapters"
        lines << "    class #{@safe_name}MemoryRepository"
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
        lines << "      def save(#{snake})"
        lines << "        @store[#{snake}.id] = #{snake}"
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
        lines.concat(query_lines(6))
        lines << ""
        lines << "      def clear"
        lines << "        @store.clear"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def query_lines(indent)
        pad = " " * indent
        [
          "#{pad}def query(conditions: {}, order_key: nil, order_direction: :asc, limit: nil, offset: nil)",
          "#{pad}  results = @store.values",
          "#{pad}  unless conditions.empty?",
          "#{pad}    results = results.select do |obj|",
          "#{pad}      conditions.all? do |k, v|",
          "#{pad}        next false unless obj.respond_to?(k)",
          "#{pad}        actual = obj.send(k)",
          "#{pad}        v.respond_to?(:match?) ? v.match?(actual) : actual == v",
          "#{pad}      end",
          "#{pad}    end",
          "#{pad}  end",
          "#{pad}  if order_key",
          "#{pad}    results = results.sort_by { |obj| val = obj.respond_to?(order_key) ? obj.send(order_key) : nil; val.nil? ? \"\" : val }",
          "#{pad}    results = results.reverse if order_direction == :desc",
          "#{pad}  end",
          "#{pad}  results = results.drop([offset, 0].max) if offset",
          "#{pad}  results = results.take([limit, 0].max) if limit",
          "#{pad}  results",
          "#{pad}end"
        ]
      end
    end
    end
  end
end
