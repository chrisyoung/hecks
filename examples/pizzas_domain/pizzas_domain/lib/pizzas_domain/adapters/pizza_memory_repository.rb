module PizzasDomain
  module Adapters
    class PizzaMemoryRepository
      include Ports::PizzaRepository

      def initialize
        @store = {}
      end

      def find(id)
        @store[id]
      end

      def save(pizza)
        @store[pizza.id] = pizza
      end

      def delete(id)
        @store.delete(id)
      end

      def all
        @store.values
      end

      def count
        @store.size
      end

      def query(conditions: {}, order_key: nil, order_direction: :asc, limit: nil, offset: nil)
        results = @store.values
        unless conditions.empty?
          results = results.select do |obj|
            conditions.all? do |k, v|
              next false unless obj.respond_to?(k)
              actual = obj.send(k)
              v.is_a?(Hecks::Querying::Operators::Operator) ? v.match?(actual) : actual == v
            end
          end
        end
        if order_key
          results = results.sort_by { |obj| val = obj.respond_to?(order_key) ? obj.send(order_key) : nil; val.nil? ? "" : val }
          results = results.reverse if order_direction == :desc
        end
        results = results.drop([offset, 0].max) if offset
        results = results.take([limit, 0].max) if limit
        results
      end

      def clear
        @store.clear
      end
    end
  end
end
