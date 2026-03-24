# Hecks::Querying::QueryBuilder
#
# Chainable query interface for aggregate repositories. Collects query
# parameters and delegates execution to the adapter's query method.
# Supports AND and OR composition via ConditionNode tree. Falls back
# to in-memory filtering via InMemoryExecutor.
#
#   Pizza.where(style: "Classic").order(:name).limit(5)
#   Pizza.where(style: "Classic").or(Pizza.where(style: "Tropical"))
#   Pizza.find_by(name: "Margherita")
#
require_relative "condition_node"
require_relative "query_builder/in_memory_executor"

module Hecks
  module Querying
    class QueryBuilder
      include Enumerable
      include InMemoryExecutor

      def initialize(repo)
        @repo = repo
        @condition_tree = ConditionNode.and
        @order_key = nil
        @order_direction = :asc
        @limit_value = nil
        @offset_value = nil
      end

      # --- Chaining ---

      def where(**conditions)
        dup.tap { |q| q.instance_variable_set(:@condition_tree, q.instance_variable_get(:@condition_tree).merge(conditions)) }
      end

      def or(other)
        dup.tap do |q|
          combined = ConditionNode.or(
            q.instance_variable_get(:@condition_tree),
            other.instance_variable_get(:@condition_tree)
          )
          q.instance_variable_set(:@condition_tree, combined)
        end
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
      def first   = execute.first
      def last    = execute.last
      def count   = execute.size
      def to_a    = execute
      def each(&block) = execute.each(&block)
      def empty?  = execute.empty?
      def exists? = !execute.empty?
      def size    = count
      alias length size

      def pluck(*keys)
        rows = execute
        keys.size == 1 ? rows.map { |r| r.send(keys.first) } : rows.map { |r| keys.map { |k| r.send(k) } }
      end

      def sum(key)     = execute.map { |r| r.send(key) }.compact.sum
      def min(key)     = execute.map { |r| r.send(key) }.compact.min
      def max(key)     = execute.map { |r| r.send(key) }.compact.max

      def average(key)
        vals = execute.map { |r| r.send(key) }.compact
        vals.empty? ? nil : vals.sum.to_f / vals.size
      end

      # Bulk delete matching records. Bypasses command bus — no events fired.
      def delete_all
        execute.each { |obj| @repo.delete(obj.id) }
      end

      # Bulk update matching records. Bypasses command bus — no events fired.
      def update_all(**attrs)
        execute.each do |obj|
          init_params = obj.class.instance_method(:initialize).parameters.map { |_, n| n }
          current = init_params.each_with_object({}) { |p, h| h[p] = obj.send(p) if obj.respond_to?(p) }
          updated = obj.class.new(**current.merge(attrs))
          @repo.save(updated)
        end
      end

      # --- Operators ---

      def gt(value)     = Operators::Gt.new(value)
      def gte(value)    = Operators::Gte.new(value)
      def lt(value)     = Operators::Lt.new(value)
      def lte(value)    = Operators::Lte.new(value)
      def not_eq(value) = Operators::NotEq.new(value)
      def one_of(values) = Operators::In.new(values)

      def inspect
        "#<Hecks::QueryBuilder condition_tree=#{@condition_tree.type} order=#{@order_key} limit=#{@limit_value}>"
      end

      private

      def execute
        # For simple AND conditions, use the adapter's native query method
        if @condition_tree.simple? && @repo.respond_to?(:query)
          @repo.query(
            conditions: @condition_tree.conditions,
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
