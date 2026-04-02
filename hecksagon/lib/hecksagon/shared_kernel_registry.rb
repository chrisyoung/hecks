# Hecksagon::SharedKernelRegistry
#
# Global registry mapping domain names to types they expose as a shared
# kernel. When a domain declares `shared_kernel` in its Bluebook, its
# value objects and entities become available to consumer domains that
# declare `uses_kernel "DomainName"`.
#
# Consumer domains get class aliases in their namespace so they can
# reference shared types without fully qualifying the source domain.
#
#   SharedKernelRegistry.register("Pricing", ["Money", "Currency"])
#   SharedKernelRegistry.types_for("Pricing")  # => ["Money", "Currency"]
#   SharedKernelRegistry.kernel?("Pricing")     # => true
#
module Hecksagon
  module SharedKernelRegistry
    @kernels = {}

    # Register a domain as a shared kernel with the types it exposes.
    #
    # @param domain_name [String] the domain name (e.g., "Pricing")
    # @param types [Array<String>] type names exposed (e.g., ["Money", "Currency"])
    # @return [void]
    def self.register(domain_name, types)
      @kernels[domain_name.to_s] = types.map(&:to_s)
    end

    # Returns the type names exposed by a shared kernel domain.
    #
    # @param domain_name [String] the domain name
    # @return [Array<String>] exposed type names, empty if not registered
    def self.types_for(domain_name)
      @kernels.fetch(domain_name.to_s, [])
    end

    # Whether a domain is registered as a shared kernel.
    #
    # @param domain_name [String] the domain name
    # @return [Boolean]
    def self.kernel?(domain_name)
      @kernels.key?(domain_name.to_s)
    end

    # All registered shared kernel domain names.
    #
    # @return [Array<String>]
    def self.all
      @kernels.keys
    end

    # Clear all registrations. Used in tests for isolation.
    #
    # @return [void]
    def self.clear!
      @kernels.clear
    end
  end
end
