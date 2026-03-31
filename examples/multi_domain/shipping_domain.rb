Hecks.domain "Shipping" do
  aggregate "Shipment" do
    attribute :pizza, String
    attribute :quantity, Integer
    attribute :status, String

    command "CreateShipment" do
      attribute :pizza, String
      attribute :quantity, Integer
    end

    command "ShipShipment" do
      attribute :shipment, String
    end

    query "ReadyToShip" do
      where(status: "pending")
    end

    # When an order is placed, create a shipment
    policy "ShipOnOrder" do
      on "PlacedOrder"
      trigger "CreateShipment"
    end
  end
end
