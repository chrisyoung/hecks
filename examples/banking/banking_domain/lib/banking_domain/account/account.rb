require 'hecks/model'

module BankingDomain
  class Account
    include Hecks::Model

    attribute :customer_id
    attribute :balance
    attribute :account_type
    attribute :daily_limit
    attribute :status, default: "open"

    private

    def validate!
      raise ValidationError, "account_type can't be blank" if account_type.nil? || (account_type.respond_to?(:empty?) && account_type.empty?)
    end
  end
end
