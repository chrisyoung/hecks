require "securerandom"

module ShippingDomain
  class ValidationError < StandardError; end
  class InvariantError < StandardError; end

  autoload :Shipment, "shipping_domain/shipment/shipment"

  module Ports
    autoload :ShipmentRepository, "shipping_domain/ports/shipment_repository"
  end

  module Adapters
    autoload :ShipmentMemoryRepository, "shipping_domain/adapters/shipment_memory_repository"
  end
end
