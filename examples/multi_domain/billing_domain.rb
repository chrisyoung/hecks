Hecks.domain "Billing" do
  aggregate "Invoice" do
    attribute :pizza, String
    attribute :quantity, Integer
    attribute :status, String

    command "CreateInvoice" do
      attribute :pizza, String
      attribute :quantity, Integer
    end

    query "Pending" do
      where(status: "pending")
    end

    # When an order is placed in the pizzas domain, create an invoice
    policy "BillOnOrder" do
      on "PlacedOrder"
      trigger "CreateInvoice"
    end
  end
end
