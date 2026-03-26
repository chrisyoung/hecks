# Hecks::ServiceSetup
#
# Wires domain services onto the domain module as callable class methods.
# Each service gets a method on the module (e.g., Banking.transfer_money)
# that instantiates the service with its attributes and runs the call body.
# The call body has access to `dispatch` for orchestrating commands.
#
#   ServiceSetup.bind(domain, mod, command_bus)
#   Banking.transfer_money(source_id: "abc", target_id: "xyz", amount: 500)
#
module Hecks
  module ServiceSetup
    def self.bind(domain, mod, command_bus)
      domain.services.each do |svc|
        wire_service(svc, mod, command_bus)
      end
    end

    def self.wire_service(svc, mod, command_bus)
      method_name = Hecks::Utils.underscore(svc.name).to_sym
      call_body = svc.call_body
      attr_names = svc.attributes.map(&:name)

      mod.define_singleton_method(method_name) do |**attrs|
        ctx = ServiceContext.new(command_bus, attr_names, attrs)
        ctx.instance_eval(&call_body) if call_body
        ctx.results
      end
    end
  end

  # Execution context for a service call body. Provides `dispatch`
  # and attribute readers so the block can orchestrate commands.
  class ServiceContext
    attr_reader :results

    def initialize(command_bus, attr_names, attrs)
      @command_bus = command_bus
      @results = []
      attr_names.each do |name|
        instance_variable_set(:"@#{name}", attrs[name])
        define_singleton_method(name) { instance_variable_get(:"@#{name}") }
      end
    end

    def dispatch(command_name, **attrs)
      result = @command_bus.dispatch(command_name, **attrs)
      @results << result
      result
    end
  end
end
