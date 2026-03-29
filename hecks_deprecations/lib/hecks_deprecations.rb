# HecksDeprecations
#
# Registry for deprecated APIs. Modules and Hecks itself register
# deprecations via +HecksDeprecations.register+, which prepends
# warning shims onto target classes.
#
#   HecksDeprecations.register(Hecks::PersistConfig, :[], method(:hash_access))
#   HecksDeprecations.registered  # => [{ target: ..., method: ... }, ...]
#
module HecksDeprecations
  @registry = []

  def self.register(target_class, method_name, &shim)
    mod = Module.new { define_method(method_name, &shim) }
    target_class.prepend(mod)
    @registry << { target: target_class, method: method_name }
  end

  def self.registered
    @registry.dup
  end

  def self.warn_deprecated(klass, method)
    warn "[DEPRECATION] #{klass}##{method} is deprecated. Use attribute accessors instead."
  end
end

require_relative "hecks_deprecations/workflow_step_compat"
require_relative "hecks_deprecations/connection_config_compat"
