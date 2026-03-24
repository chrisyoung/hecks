Hecks.domain "Banking" do
  aggregate "Customer" do
    attribute :name, String
    attribute :email, String
    attribute :status, String
    attribute :address, list_of("Address")

    value_object "Address" do
      attribute :street, String
      attribute :city, String
      attribute :state, String
      attribute :zip, String
    end

    validation :name, {:presence=>true}

    validation :email, {:presence=>true}

    command "RegisterCustomer" do
      attribute :name, String
      attribute :email, String
    end

    command "SuspendCustomer" do
      attribute :customer_id, String
    end

    command "NotifyCustomer" do
      attribute :customer_id, String
      attribute :message, String
    end

    on_event "RegisteredCustomer" do |event|
      puts "Welcome email sent to #{event.email}"
    end
  end

  aggregate "Account" do
    attribute :customer_id, reference_to("Customer")
    attribute :balance, Float
    attribute :account_type, String
    attribute :daily_limit, Float
    attribute :status, String

    validation :account_type, {:presence=>true}

    query "ByCustomer" do
      where(customer_id: customer_id)
    end

    command "OpenAccount" do
      attribute :customer_id, String
      attribute :account_type, String
      attribute :daily_limit, Float
    end

    command "Deposit" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "Withdraw" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "FlagSuspiciousActivity" do
      attribute :account_id, String
      attribute :reason, String
    end

    command "CloseAccount" do
      attribute :account_id, String
    end

    policy "FraudAlert" do
      on "Withdrew"
      trigger "FlagSuspiciousActivity"
    end

    on_event "Deposited" do |event|
      puts "Deposit receipt for account #{event.account_id}: $#{event.amount}"
    end
  end

  aggregate "Transfer" do
    attribute :from_account_id, reference_to("Account")
    attribute :to_account_id, reference_to("Account")
    attribute :amount, Float
    attribute :status, String
    attribute :memo, String

    validation :amount, {:presence=>true}

    query "HighValue" do
      where(amount: Hecks::Services::Querying::Operators::Gte.new(1000.0))
    end

    command "InitiateTransfer" do
      attribute :from_account_id, String
      attribute :to_account_id, String
      attribute :amount, Float
      attribute :memo, String
    end

    command "CompleteTransfer" do
      attribute :transfer_id, String
    end

    command "RejectTransfer" do
      attribute :transfer_id, String
    end

    on_event "CompletedTransfer" do |event|
      puts "Transfer #{event.transfer_id} completed — notify both parties"
    end
  end

  aggregate "Loan" do
    attribute :customer_id, reference_to("Customer")
    attribute :account_id, reference_to("Account")
    attribute :principal, Float
    attribute :rate, Float
    attribute :term_months, Integer
    attribute :status, String
    attribute :remaining_balance, Float
    attribute :payment_schedule, list_of("PaymentScheduleEntry")

    value_object "PaymentScheduleEntry" do
      attribute :due_date, String
      attribute :principal_amount, Float
      attribute :interest_amount, Float
      attribute :total_amount, Float
    end

    value_object "Disbursement" do
      attribute :amount, Float
      attribute :disbursed_at, String
      attribute :method, String
    end

    validation :principal, {:presence=>true}

    validation :rate, {:presence=>true}

    invariant "rate must be between 0 and 100" do
      rate.nil? || (rate >= 0 && rate <= 100)
    end

    query "ByCustomer" do
      where(customer_id: customer_id)
    end

    query "Delinquent" do
      where(status: "defaulted")
    end

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :account_id, String
      attribute :principal, Float
      attribute :rate, Float
      attribute :term_months, Integer
    end

    command "MakePayment" do
      attribute :loan_id, String
      attribute :amount, Float
    end

    command "DefaultLoan" do
      attribute :loan_id, String
      attribute :reason, String
    end

    command "RefinanceLoan" do
      attribute :loan_id, String
      attribute :new_rate, Float
      attribute :new_term_months, Integer
    end

    policy "DisburseFunds" do
      on "IssuedLoan"
      trigger "Deposit"
    end

    policy "SuspendOnDefault" do
      on "DefaultedLoan"
      trigger "SuspendCustomer"
    end

    on_event "MadePayment" do |event|
      puts "Payment of $#{event.amount} received for loan #{event.loan_id}"
    end
  end
end
