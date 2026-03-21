Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :description, String
    attribute :toppings, list_of("Topping")

    value_object "Topping" do
      attribute :name, String
      attribute :amount, Integer

      invariant "amount must be positive" do
        amount > 0
      end
    end

    validation :name, presence: true

    command "CreatePizza" do
      attribute :name, String
      attribute :description, String
    end

    command "AddTopping" do
      attribute :pizza_id, reference_to("Pizza")
      attribute :topping, String
    end
  end

  aggregate "Order" do
    attribute :pizza_id, reference_to("Pizza")
    attribute :quantity, Integer
    attribute :status, String

    validation :quantity, presence: true

    command "PlaceOrder" do
      attribute :pizza_id, reference_to("Pizza")
      attribute :quantity, Integer
    end

    command "CancelOrder" do
      attribute :pizza_id, reference_to("Pizza")
    end

    command "ReserveStock" do
      attribute :pizza_id, reference_to("Pizza")
      attribute :quantity, Integer
    end

    policy "ReserveIngredients" do
      on "PlacedOrder"
      trigger "ReserveStock"
    end
  end
end
