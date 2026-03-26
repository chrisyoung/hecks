# Hecks::DomainModel::Behavior::Condition
#
# A named assertion on a command — either a precondition (checked before
# execution against the current aggregate state) or a postcondition
# (checked after execution by comparing before/after state).
#
#   pre = Condition.new(message: "sufficient funds", block: ->(agg) { agg.balance >= 100 })
#   post = Condition.new(message: "balance decreased", block: ->(before, after) { ... })
#
module Hecks
  module DomainModel
    module Behavior
      class Condition
        attr_reader :message, :block

        def initialize(message:, block:)
          @message = message
          @block = block
        end
      end
    end
  end
end
