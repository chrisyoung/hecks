module PizzaBuilder
  module Domain
    module Pizzas
      class Repository
        @collection = {}
        @last_id    = 0

        def self.create id, attributes
          @collection[id] = Pizza.new(attributes.merge(id: id))
          @last_id        = id
          Struct.new(:id).new(id)
        end

        def self.update id, attributes
          entity = read id

          return unless entity
          attributes.each do |field, value|
            entity.send("#{field}=", value)
          end

          entity
        end

        def self.read id
          @collection[id]
        end

        def self.delete(id)
          @collection.delete(id)
        end

        def self.delete_all
          @collection = {}
          @last_id    = 0
        end
      end
    end
  end
end
