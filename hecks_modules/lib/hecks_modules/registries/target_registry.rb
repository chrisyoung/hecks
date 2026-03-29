# Hecks::TargetRegistryMethods
#
# Registry for build targets. Each target (ruby, static, go, rails) registers
# a callable that receives a domain and options, and returns the build output.
#
#   Hecks.register_target(:go) { |domain, **opts| Hecks.build_go(domain, **opts) }
#   Hecks.target_registry[:go].call(domain)
#
module Hecks
  module TargetRegistryMethods
    extend ModuleDSL

    lazy_registry :target_registry

    def register_target(name, &builder)
      target_registry[name.to_sym] = builder
    end
  end
end
