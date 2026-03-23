# Hecks::Services::Persistence::CollectionItem
#
# Wraps a value object from a collection, delegating all methods to the
# underlying object but adding delete/destroy that remove it from the
# parent collection.
#
#   pizza.toppings.first.delete   # removes and persists
#   pizza.toppings.first.name     # delegates to the value object
#
module Hecks
  module Services
    module Persistence
      class CollectionItem
        def initialize(raw, collection)
          @raw = raw
          @collection = collection
        end

        def delete
          @collection.delete(self)
          @raw
        end
        alias destroy delete

        def __raw__
          @raw
        end

        def ==(other)
          if other.is_a?(CollectionItem)
            @raw == other.__raw__
          else
            @raw == other
          end
        end
        alias eql? ==

        def hash
          @raw.hash
        end

        def frozen?
          @raw.frozen?
        end

        def class
          @raw.class
        end

        def is_a?(klass)
          @raw.is_a?(klass) || super
        end

        def inspect
          @raw.inspect
        end

        def respond_to_missing?(method, include_private = false)
          @raw.respond_to?(method, include_private) || super
        end

        def method_missing(method, *args, &block)
          if @raw.respond_to?(method)
            @raw.send(method, *args, &block)
          else
            super
          end
        end
      end
    end
  end
end
