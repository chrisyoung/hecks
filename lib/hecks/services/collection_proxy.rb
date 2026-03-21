# Hecks::Services::CollectionProxy
#
# Wraps a list attribute on an aggregate, providing create/delete/count
# methods that rebuild the aggregate with the modified collection and
# save it back to the repo.
#
# Behaves like an Array for reading (each, map, size, etc.) but adds
# persistence-aware mutations.
#
#   pizza = Pizza.create(name: "Margherita")
#   pizza.toppings.create(name: "Mozzarella", amount: 2)
#   pizza.toppings.create(name: "Basil", amount: 1)
#   pizza.toppings.count   # => 2
#   pizza.toppings.each { |t| puts t.name }
#
module Hecks
  module Services
    class CollectionProxy
      include Enumerable

      def initialize(items:, owner:, attr_name:, value_object_class:, repo:)
        @items = items || []
        @owner = owner
        @attr_name = attr_name
        @value_object_class = value_object_class
        @repo = repo
      end

      def create(**attrs)
        item = @value_object_class.new(**attrs)
        new_items = @items + [item]
        rebuild_owner(new_items)
        wrap(item)
      end

      def delete(item)
        raw = item.is_a?(CollectionItem) ? item.__raw__ : item
        new_items = @items.reject { |i| i == raw }
        rebuild_owner(new_items)
        item
      end

      def clear
        rebuild_owner([])
        self
      end

      def each(&block)
        @items.each { |item| block.call(wrap(item)) }
      end

      def size
        @items.size
      end
      alias count size
      alias length size

      def empty?
        @items.empty?
      end

      def any?(&block)
        block ? @items.any?(&block) : @items.any?
      end

      def first
        item = @items.first
        item ? wrap(item) : nil
      end

      def last
        item = @items.last
        item ? wrap(item) : nil
      end

      def [](index)
        item = @items[index]
        item ? wrap(item) : nil
      end

      def to_a
        @items.map { |item| wrap(item) }
      end

      def inspect
        @items.inspect
      end

      private

      def wrap(item)
        CollectionItem.new(item, self)
      end

      def rebuild_owner(new_items)
        # Get all current attributes from the owner
        constructor_params = @owner.class.instance_method(:initialize).parameters
        attrs = {}
        constructor_params.each do |_, name|
          next unless name
          if name == @attr_name
            attrs[name] = new_items
          elsif name == :id
            attrs[:id] = @owner.id
          elsif @owner.respond_to?(name)
            attrs[name] = @owner.send(name)
          end
        end

        # Build new aggregate instance and save
        new_owner = @owner.class.new(**attrs)
        @repo.save(new_owner)

        # Update our items reference
        @items = new_items.freeze

        # Update the owner's instance variable
        @owner.instance_variable_set(:"@#{@attr_name}", new_items.freeze)

        new_owner
      end
    end

    # Wraps a value object from a collection, delegating all methods to the
    # underlying object but adding delete/destroy that remove it from the
    # parent collection.
    #
    #   pizza.toppings.first.delete   # removes from pizza and persists
    #   pizza.toppings.first.name     # delegates to the Topping
    #
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
