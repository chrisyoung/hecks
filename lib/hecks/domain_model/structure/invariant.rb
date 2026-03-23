# Hecks::DomainModel::Structure::Invariant
#
# A business rule that must always hold true for an aggregate or value object.
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
