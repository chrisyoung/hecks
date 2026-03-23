module PizzasDomain
  class Order

    module Commands
      autoload :PlaceOrder, "pizzas_domain/order/commands/place_order"
    end

    module Events
      autoload :PlacedOrder, "pizzas_domain/order/events/placed_order"
    end

    attr_reader :id, :pizza_id, :quantity, :created_at, :updated_at

    def initialize(pizza_id: nil, quantity: nil, id: nil, created_at: nil, updated_at: nil)
      @id = id || generate_id
      @pizza_id = pizza_id
      @quantity = quantity
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
