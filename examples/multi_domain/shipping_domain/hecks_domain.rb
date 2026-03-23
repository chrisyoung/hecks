Hecks.domain "Shipping" do
  aggregate "Shipment" do
    attribute :pizza_id, String
    attribute :quantity, Integer
    attribute :status, String

    query "ReadyToShip" do
      where(status: "pending")
    end

    command "CreateShipment" do
      attribute :pizza_id, String
      attribute :quantity, Integer
    end

    command "ShipShipment" do
      attribute :shipment_id, String
    end

    policy "ShipOnOrder" do
      on "PlacedOrder"
      trigger "CreateShipment"
    end
  end
end
