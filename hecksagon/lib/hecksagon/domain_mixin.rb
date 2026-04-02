module Hecksagon

  # Hecksagon::DomainMixin
  #
  # Extends Domain IR objects with hexagonal accessors.
  # Applied automatically when heksagons is loaded.
  #
  module DomainMixin
    attr_accessor :driving_ports, :driven_ports,
                  :shared_kernel, :uses_kernels,
                  :anti_corruption_layers, :published_events,
                  :classification

    def shared_kernel?
      @shared_kernel == true
    end

    # Returns the domain classification, defaulting to :supporting.
    #
    # @return [Symbol] one of :core, :supporting, :generic
    def domain_classification
      @classification || :supporting
    end

    def core?
      domain_classification == :core
    end

    def supporting?
      domain_classification == :supporting
    end

    def generic?
      domain_classification == :generic
    end
  end
end
