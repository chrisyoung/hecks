# Hecks::ExtensionRegistryMethods
#
# Extension hook and metadata storage. Extracted from the Hecks module
# to give extensions a focused home.
#
module Hecks
  module ExtensionRegistryMethods
    def extension_registry
      @extension_registry
    end

    def extension_meta
      @extension_meta
    end

    def register_extension(name, &hook)
      @extension_registry[name.to_sym] = hook
    end

    def describe_extension(name, description:, config: {}, wires_to: nil)
      @extension_meta[name.to_sym] = {
        description: description, config: config, wires_to: wires_to
      }
    end
  end
end
