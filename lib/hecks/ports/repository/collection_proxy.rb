# Hecks::Persistence::CollectionProxy
#
# Wraps a list attribute on an aggregate, providing create/delete/count
# methods that rebuild the aggregate with the modified collection and
# save it back to the repo.
#
# Behaves like an Array for reading (each, map, size, etc.) but adds
# persistence-aware mutations. Items are wrapped in CollectionItem so
# they support .delete directly.
#
#   pizza = Pizza.create(name: "Margherita")
#   pizza.toppings.create(name: "Mozzarella", amount: 2)
#   pizza.toppings.count          # => 2
#   pizza.toppings.first.delete   # removes and persists
#
require_relative "collection_item"

module Hecks
  module Persistence
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
          found = false
          new_items = @items.reject { |i| !found && i == raw && (found = true) }
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

        def +(other)
          @items + Array(other)
        end

        def inspect
          @items.inspect
        end

        private

        def wrap(item)
          CollectionItem.new(item, self)
        end

        def rebuild_owner(new_items)
          attrs = { id: @owner.id }
          if @owner.class.respond_to?(:hecks_attributes)
            @owner.class.hecks_attributes.each do |a|
              attrs[a[:name]] = a[:name] == @attr_name ? new_items : @owner.send(a[:name])
            end
          else
            @owner.class.instance_method(:initialize).parameters.each do |_, name|
              next unless name
              if name == @attr_name
                attrs[name] = new_items
              elsif name != :id && @owner.respond_to?(name)
                attrs[name] = @owner.send(name)
              end
            end
          end

          new_owner = @owner.class.new(**attrs)
          new_owner.instance_variable_set(:@created_at, @owner.created_at) if @owner.respond_to?(:created_at)
          @repo.save(new_owner)

          @items = new_items.freeze
          @owner.instance_variable_set(:"@#{@attr_name}", new_items.freeze)

          new_owner
        end
      end
  end
end
