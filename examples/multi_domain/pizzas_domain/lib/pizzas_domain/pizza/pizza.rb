module PizzasDomain
  class Pizza

    module Commands
      autoload :CreatePizza, "pizzas_domain/pizza/commands/create_pizza"
    end

    module Events
      autoload :CreatedPizza, "pizzas_domain/pizza/events/created_pizza"
    end

    module Queries
      autoload :Classics, "pizzas_domain/pizza/queries/classics"
    end

    attr_reader :id, :name, :style, :price, :created_at, :updated_at

    def initialize(name: nil, style: nil, price: nil, id: nil, created_at: nil, updated_at: nil)
      @id = id || generate_id
      @name = name
      @style = style
      @price = price
      @created_at = created_at || Time.now
      @updated_at = updated_at || Time.now
      validate!
      check_invariants!
    end

    def ==(other)
      other.is_a?(self.class) && id == other.id
    end
    alias eql? ==

    def hash
      [self.class, id].hash
    end

    private

    def generate_id
      SecureRandom.uuid
    end

    def validate!; end

    def check_invariants!; end
  end
end
