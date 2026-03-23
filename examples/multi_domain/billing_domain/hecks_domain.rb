Hecks.domain "Billing" do
  aggregate "Invoice" do
    attribute :pizza_id, String
    attribute :quantity, Integer
    attribute :status, String

    query "Pending" do
      true
    end

    command "CreateInvoice" do
      attribute :pizza_id, String
      attribute :quantity, Integer
    end

    policy "BillOnOrder" do
      on "PlacedOrder"
      trigger "CreateInvoice"
    end
  end
end
