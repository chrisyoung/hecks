# Hecks::DomainModel::Structure::Invariant
#
# A business rule that must always hold true for an aggregate or value object.
# Invariants carry a human-readable message and an optional block that
# evaluates the constraint at runtime.
#
# Part of the DomainModel IR layer. Consumed by generators to produce
# validation logic in domain gem classes.
#
#   inv = Invariant.new(message: "name is required", block: proc { !name.nil? })
#   inv.message  # => "name is required"
#   inv.block    # => #<Proc>
#
module Hecks
  module DomainModel
    module Structure
    class Invariant
      attr_reader :message, :block

      def initialize(message:, block: nil)
        @message = message
        @block = block
      end
    end
    end
  end
end
