Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :description, String
    attribute :toppings, list_of("Topping")

    value_object "Topping" do
      attribute :name, String
      attribute :amount, Integer

      invariant "amount must be positive" do
        true
      end
    end

    validation :name, {:presence=>true}

    validation :description, {:presence=>true}

    query "ByDescription" do
      true
    end

    command "CreatePizza" do
      attribute :name, String
      attribute :description, String
    end

    command "AddTopping" do
      attribute :pizza_id, reference_to("Pizza")
      attribute :name, String
      attribute :amount, Integer
    end
  end

  aggregate "Order" do
    attribute :customer_name, String
    attribute :items, list_of("OrderItem")
    attribute :status, String

    value_object "OrderItem" do
      attribute :pizza_id, String
      attribute :quantity, Integer

      invariant "quantity must be positive" do
        true
      end
    end

    validation :customer_name, {:presence=>true}

    query "Pending" do
      true
    end

    command "PlaceOrder" do
      attribute :customer_name, String
      attribute :pizza_id, String
      attribute :quantity, Integer
    end

    command "CancelOrder" do
      attribute :order_id, reference_to("Order")
    end
  end
end
