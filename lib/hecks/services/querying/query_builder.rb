# Hecks::Services::Querying::QueryBuilder
#
# Chainable query interface for aggregate repositories. Collects query
# parameters and delegates execution to the adapter's query method.
# Falls back to in-memory filtering via InMemoryExecutor.
#
#   Pizza.where(style: "Classic").order(:name).limit(5)
#   Pizza.find_by(name: "Margherita")
#
require_relative "query_builder/in_memory_executor"

module Hecks
  module Services
    module Querying
      class QueryBuilder
      include Enumerable
      include InMemoryExecutor

      def initialize(repo)
        @repo = repo
        @conditions = {}
        @order_key = nil
        @order_direction = :asc
        @limit_value = nil
        @offset_value = nil
      end

      # --- Chaining ---

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

      # --- Terminals ---

      def find_by(**conditions) = where(**conditions).first
      def first  = execute.first
      def last   = execute.last
      def count  = execute.size
      def to_a   = execute
      def each(&block) = execute.each(&block)
      def empty? = execute.empty?
      def size   = count
      alias length size

      # --- Operators ---

      def gt(value)     = Operators::Gt.new(value)
      def gte(value)    = Operators::Gte.new(value)
      def lt(value)     = Operators::Lt.new(value)
      def lte(value)    = Operators::Lte.new(value)
      def not_eq(value) = Operators::NotEq.new(value)
      def one_of(values) = Operators::In.new(values)

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
          in_memory_execute
        end
      end
      end
    end
  end
end
