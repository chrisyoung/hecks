module Heksagons

  # Heksagons::AdapterRegistry
  #
  # Formalizes adapter registration. Adapters implement driven ports.
  #
  #   Heksagons.register_adapter(:sqlite, for: :persistence) do |config|
  #     # wiring logic
  #   end
  #
  #   Heksagons.adapters_for(:persistence)  # => [:memory, :sqlite]
  #   Heksagons.adapter(:sqlite)            # => { port: :persistence, hook: Proc }
  #
  module AdapterRegistry
    def adapter_registry
      @adapter_registry ||= {}
    end

    def register_adapter(name, for_port: nil, implements: [], &hook)
      adapter_registry[name.to_sym] = {
        name: name.to_sym,
        port: for_port&.to_sym,
        implements: implements.map(&:to_sym),
        hook: hook
      }
    end

    def adapter(name)
      adapter_registry[name.to_sym]
    end

    def adapters_for(port_name)
      adapter_registry.values
        .select { |a| a[:port] == port_name.to_sym }
        .map { |a| a[:name] }
    end

    def all_adapters
      adapter_registry.keys
    end
  end
end
