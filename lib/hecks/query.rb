# Hecks::Query
#
# Mixin for generated query classes. Provides repository wiring and
# delegates query methods (where, order, limit, etc.) to a QueryBuilder.
# The generated call method is pure domain logic — describes the query.
#
#   class Classics
#     include Hecks::Query
#
#     def call
#       where(style: "Classic").order(:name)
#     end
#   end
#
#   Classics.call          # => QueryBuilder (chainable)
#   Classics.call.to_a     # => [#<Pizza>, ...]
#
module Hecks
  module Query
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      attr_accessor :repository

      def call(*args)
        instance = new
        instance.send(:with_builder, *args)
      end
    end

    private

    def with_builder(*args)
      @builder = Services::Querying::QueryBuilder.new(self.class.repository)
      result = call(*args)
      result.is_a?(Services::Querying::QueryBuilder) ? result : @builder
    end

    def where(**conditions)
      @builder = @builder.where(**conditions)
    end

    def order(key)
      @builder = @builder.order(key)
    end

    def limit(n)
      @builder = @builder.limit(n)
    end

    def offset(n)
      @builder = @builder.offset(n)
    end

    def gt(value)     = Services::Querying::Operators::Gt.new(value)
    def gte(value)    = Services::Querying::Operators::Gte.new(value)
    def lt(value)     = Services::Querying::Operators::Lt.new(value)
    def lte(value)    = Services::Querying::Operators::Lte.new(value)
    def not_eq(value) = Services::Querying::Operators::NotEq.new(value)
    def one_of(values) = Services::Querying::Operators::In.new(values)
  end
end
