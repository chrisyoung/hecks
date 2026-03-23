# Hecks::Services::Querying::QueryBuilder
#
# Chainable query interface for aggregate repositories. Collects query
# parameters and delegates execution to the adapter's query method.
# Supports where, order, limit, offset, find_by, first, last, and count.
# Falls back to in-memory filtering for adapters without query support.
#
#   Pizza.where(style: "Classic").order(:name).limit(5)
#   Pizza.where(status: "active").count
#   Pizza.find_by(name: "Margherita")
#
module Hecks
  module Services
    module Querying
      class QueryBuilder
      include Enumerable

      def initialize(repo)
        @repo = repo
        @conditions = {}
        @order_key = nil
        @order_direction = :asc
        @limit_value = nil
        @offset_value = nil
      end

      def where(**conditions)
        dup.tap { |q| q.instance_variable_get(:@conditions).merge!(conditions) }
      end

      def order(key_or_hash)
        dup.tap do |q|
          if key_or_hash.is_a?(Hash)
            key = key_or_hash.keys.first
            dir = key_or_hash.values.first
            q.instance_variable_set(:@order_key, key)
            q.instance_variable_set(:@order_direction, dir)
          else
            q.instance_variable_set(:@order_key, key_or_hash)
            q.instance_variable_set(:@order_direction, :asc)
          end
        end
      end

      def limit(n)
        dup.tap { |q| q.instance_variable_set(:@limit_value, n) }
      end

      def offset(n)
        dup.tap { |q| q.instance_variable_set(:@offset_value, n) }
      end

      def find_by(**conditions)
        where(**conditions).first
      end

      def first
        execute.first
      end

      def last
        execute.last
      end

      def count
        execute.size
      end

      def to_a
        execute
      end

      def each(&block)
        execute.each(&block)
      end

      def empty?
        execute.empty?
      end

      def size
        count
      end
      alias length size

      def inspect
        "#<Hecks::QueryBuilder conditions=#{@conditions} order=#{@order_key} limit=#{@limit_value}>"
      end

      private

      def execute
        if @repo.respond_to?(:query)
          @repo.query(
            conditions: @conditions,
            order_key: @order_key,
            order_direction: @order_direction,
            limit: @limit_value,
            offset: @offset_value
          )
        else
          results = @repo.all
          results = apply_conditions(results)
          results = apply_order(results)
          results = apply_offset(results)
          results = apply_limit(results)
          results
        end
      end

      def apply_conditions(results)
        return results if @conditions.empty?

        results.select do |obj|
          @conditions.all? { |k, v| obj.respond_to?(k) && obj.send(k) == v }
        end
      end

      def apply_order(results)
        return results unless @order_key

        sorted = results.sort_by do |obj|
          val = obj.respond_to?(@order_key) ? obj.send(@order_key) : nil
          val.nil? ? "" : val
        end

        @order_direction == :desc ? sorted.reverse : sorted
      end

      def apply_offset(results)
        return results unless @offset_value
        results.drop(@offset_value)
      end

      def apply_limit(results)
        return results unless @limit_value
        results.take(@limit_value)
      end
      end
    end
  end
end
