module Heksagons

  # Heksagons::PortDSL
  #
  # Mixin for domain builders. Adds driving_port and driven_port DSL methods.
  # Include in any builder that should support hexagonal port declarations.
  #
  #   class MyBuilder
  #     include Heksagons::PortDSL
  #   end
  #
  module PortDSL
    def self.included(base)
      base.class_eval do
        def init_ports
          @driving_ports ||= []
          @driven_ports ||= []
        end
      end
    end

    # Declare an inbound interface (driving/primary port).
    #   driving_port :http, description: "REST API"
    #   driving_port :mcp, description: "AI tool interface"
    def driving_port(name, description: nil)
      init_ports
      @driving_ports << { name: name.to_sym, description: description }
    end

    # Declare an outbound dependency (driven/secondary port).
    #   driven_port :persistence, [:find, :save, :delete, :all]
    #   driven_port :notifications, [:send_email, :send_sms]
    def driven_port(name, methods = [], description: nil)
      init_ports
      @driven_ports << { name: name.to_sym, methods: methods.map(&:to_sym), description: description }
    end
  end
end
