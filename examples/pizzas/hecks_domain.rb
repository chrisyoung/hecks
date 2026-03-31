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
    validation :description, presence: true

    command "CreatePizza" do
      attribute :name, String
      attribute :description, String
    end

    query "ByDescription" do |desc|
      where(description: desc)
    end

    command "AddTopping" do
      reference_to "Pizza"
      attribute :name, String
      attribute :amount, Integer
    end

    port :admin do
      allow :find, :all, :create_pizza, :add_topping
    end

    port :customer do
      allow :find, :all
    end
  end

  aggregate "Order" do
    attribute :customer_name, String
    attribute :items, list_of("OrderItem")
    attribute :status, String, default: "pending"
    reference_to "Pizza"

    value_object "OrderItem" do
      attribute :quantity, Integer

      invariant "quantity must be positive" do
        quantity > 0
      end
    end

    validation :customer_name, presence: true

    command "PlaceOrder" do
      attribute :customer_name, String
      reference_to "Pizza"
      attribute :quantity, Integer
    end

    command "CancelOrder" do
      reference_to "Order"
    end

    lifecycle :status, default: "pending" do
      transition "CancelOrder" => "cancelled"
    end

    query "Pending" do
      where(status: "pending")
    end

    port :admin do
      allow :find, :all, :place_order, :cancel_order
    end

    port :customer do
      allow :find, :all, :place_order
    end
  end
end
