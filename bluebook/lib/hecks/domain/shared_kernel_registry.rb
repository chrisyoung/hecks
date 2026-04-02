module Hecks
  # Hecks::SharedKernelRegistry
  #
  # Global registry mapping shared kernel domain names to their compiled
  # Domain IR objects. When a domain declares `uses_kernel "Shared"`, the
  # InMemoryLoader looks up "Shared" in this registry and loads its value
  # objects as type aliases in the consuming domain's namespace.
  #
  # Kernels must be registered before consuming domains are loaded.
  #
  #   Hecks::SharedKernelRegistry.register("Shared", shared_domain)
  #   Hecks::SharedKernelRegistry.lookup("Shared")
  #   # => #<Domain name="Shared" ...>
  #
  #   Hecks::SharedKernelRegistry.kernel_types("Shared")
  #   # => [#<ValueObject name="Money" ...>, ...]
  #
  class SharedKernelRegistry
    @kernels = {}

    class << self
      # Register a domain as a shared kernel.
      #
      # @param name [String] the kernel domain name
      # @param domain [DomainModel::Structure::Domain] the compiled domain IR
      # @return [void]
      def register(name, domain)
        @kernels[name.to_s] = domain
      end

      # Look up a registered kernel domain.
      #
      # @param name [String] the kernel domain name
      # @return [DomainModel::Structure::Domain, nil]
      def lookup(name)
        @kernels[name.to_s]
      end

      # Returns all value objects from all aggregates in a kernel domain.
      # These are the shared types available for aliasing.
      #
      # @param name [String] the kernel domain name
      # @return [Array<DomainModel::Structure::ValueObject>]
      def kernel_types(name)
        domain = lookup(name)
        return [] unless domain
        domain.aggregates.flat_map(&:value_objects)
      end

      # Clear all registered kernels (for testing).
      #
      # @return [void]
      def clear
        @kernels.clear
      end

      # All registered kernel names.
      #
      # @return [Array<String>]
      def registered
        @kernels.keys
      end
    end
  end
end
