# Hecks::ExtensionDispatch
#
# Resolves hecksagon concerns into extensions and capabilities at boot
# time. Called by the boot sequence after extensions are fired, so that
# concern-driven capabilities layer on top of explicitly declared
# extensions without conflicting.
#
# Usage:
#   Hecks::ExtensionDispatch.apply_hecksagon_concerns(runtime)
#
require_relative "../concerns/mapping"
require_relative "../capabilities/audit"

module Hecks
  module ExtensionDispatch
    # Reads concerns from the hecksagon IR attached to the runtime and
    # activates the corresponding extensions and capabilities.
    #
    # Extensions are loaded via LoadExtensions.require_one and fired
    # through the extension registry. Capabilities are activated via
    # their own apply method.
    #
    # @param runtime [Hecks::Runtime] a booted runtime with @hecksagon set
    # @return [void]
    def self.apply_hecksagon_concerns(runtime)
      hecksagon = runtime.instance_variable_get(:@hecksagon)
      return unless hecksagon
      return if hecksagon.concerns.empty?

      resolved = Concerns::Mapping.resolve_all(hecksagon.concerns)
      activate_extensions(resolved[:extensions], runtime)
      activate_capabilities(resolved[:capabilities], runtime)
    end

    # Load and fire extensions that are not yet registered.
    #
    # @param extension_names [Array<Symbol>] extension names
    # @param runtime [Hecks::Runtime] the runtime
    # @return [void]
    def self.activate_extensions(extension_names, runtime)
      mod = runtime.instance_variable_get(:@mod)
      domain = runtime.domain

      extension_names.each do |name|
        LoadExtensions.require_one(name)
        hook = Hecks.extension_registry[name]
        next unless hook
        hook.call(mod, domain, runtime)
      end
    end

    # Activate capabilities by name.
    #
    # @param capability_names [Array<Symbol>] capability names
    # @param runtime [Hecks::Runtime] the runtime
    # @return [void]
    def self.activate_capabilities(capability_names, runtime)
      capability_names.each do |name|
        case name
        when :audit
          Capabilities::Audit.apply(runtime)
        end
      end
    end

    private_class_method :activate_extensions, :activate_capabilities
  end
end
