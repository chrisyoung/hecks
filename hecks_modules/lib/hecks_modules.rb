# HecksModules
#
# Module infrastructure for Hecks. Provides Registry and SetRegistry
# base classes, ModuleDSL for custom extensions, and all registry
# mixins for the Hecks module.
#
#   targets = Hecks::Registry.new
#   targets.register(:ruby) { |domain| build(domain) }
#
module Hecks; end

require_relative "hecks_modules/registry"
require_relative "hecks_modules/set_registry"
require_relative "hecks_modules/module_dsl"
require_relative "hecks_modules/core_extensions"
require_relative "hecks_modules/registries/extension_registry"
require_relative "hecks_modules/registries/domain_registry"
require_relative "hecks_modules/registries/cross_domain"
require_relative "hecks_modules/registries/thread_context"
require_relative "hecks_modules/registries/target_registry"
require_relative "hecks_modules/registries/adapter_registry"
require_relative "hecks_modules/registries/validation_registry"
require_relative "hecks_modules/registries/dump_format_registry"
require_relative "hecks_modules/registries/grammar_registry"
