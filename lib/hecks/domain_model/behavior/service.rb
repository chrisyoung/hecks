# Hecks::DomainModel::Behavior::Service
#
# Domain service definition in the intermediate representation. Services
# orchestrate multiple commands across aggregates. They have attributes
# (inputs) and a call body (the orchestration logic with dispatch).
#
#   Service.new(name: "TransferMoney", attributes: [...], call_body: proc)
#
module Hecks
  module DomainModel
    module Behavior
      class Service
        attr_reader :name, :attributes, :call_body

        def initialize(name:, attributes: [], call_body: nil)
          @name = name
          @attributes = attributes
          @call_body = call_body
        end
      end
    end
  end
end
