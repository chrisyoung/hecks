# HecksModules
#
# Module infrastructure for Hecks. Provides the ModuleDSL for declaring
# lazy registries, all registry mixins for the Hecks module, and
# module discovery for CLI command grouping.
#
#   require "hecks_modules"
#
#   module MyRegistryMethods
#     extend Hecks::ModuleDSL
#     lazy_registry :widgets
#   end
#
module Hecks; end

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
