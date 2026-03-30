module Heksagons

  # Heksagons::DomainMixin
  #
  # Extends Domain IR objects with hexagonal port accessors.
  # Applied automatically when heksagons is loaded.
  #
  module DomainMixin
    attr_accessor :driving_ports, :driven_ports
  end
end
