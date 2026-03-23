Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :style, String
    attribute :price, Float

    command "CreatePizza" do
      attribute :name, String
      attribute :style, String
      attribute :price, Float
    end
  end

  aggregate "Order" do
    attribute :pizza_id, reference_to("Pizza")
    attribute :quantity, Integer

    command "PlaceOrder" do
      attribute :pizza_id, reference_to("Pizza")
      attribute :quantity, Integer
    end
  end
end
