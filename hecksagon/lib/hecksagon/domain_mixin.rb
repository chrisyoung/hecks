module Hecksagon

  # Hecksagon::DomainMixin
  #
  # Extends Domain IR objects with hexagonal accessors: ports, shared kernels,
  # anti-corruption layers, published events, and domain classification.
  #
  #   domain.classification  # => :core
  #   domain.core?           # => true
  #   domain.supporting?     # => false
  #   domain.generic?        # => false
  #
  module DomainMixin
    attr_accessor :driving_ports, :driven_ports,
                  :shared_kernel, :uses_kernels,
                  :anti_corruption_layers, :published_events,
                  :classification

    def shared_kernel?
      @shared_kernel == true
    end

    # @return [Boolean] true if this domain is classified as core
    def core?
      @classification == :core
    end

    # @return [Boolean] true if this domain is classified as supporting
    def supporting?
      @classification == :supporting
    end

    # @return [Boolean] true if this domain is classified as generic
    def generic?
      @classification == :generic
    end
  end
end
