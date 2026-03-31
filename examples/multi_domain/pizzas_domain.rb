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

    query "Classics" do
      where(style: "Classic")
    end
  end

  aggregate "Order" do
    reference_to "Pizza"
    attribute :quantity, Integer

    command "PlaceOrder" do
      reference_to "Pizza"
      attribute :quantity, Integer
    end
  end
end
