# Hecks::DSL::ServiceBuilder
#
# DSL builder for domain service definitions. Services orchestrate
# multiple commands across aggregates. The call block has access to
# `dispatch(command_name, **attrs)` and the service's own attributes.
#
#   builder = ServiceBuilder.new("TransferMoney")
#   builder.attribute :source_id, String
#   builder.attribute :amount, Float
#   builder.call { dispatch("Withdraw", account_id: source_id, amount: amount) }
#   service = builder.build
#
module Hecks
  module DSL
    class ServiceBuilder
      include AttributeCollector

      def initialize(name)
        @name = name
        @attributes = []
        @call_body = nil
      end

      def call(&block)
        @call_body = block
      end

      def build
        DomainModel::Behavior::Service.new(
          name: @name,
          attributes: @attributes,
          call_body: @call_body
        )
      end
    end
  end
end
