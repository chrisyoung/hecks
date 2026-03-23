# Hecks::Generators::Infrastructure
#
# Infrastructure generators: ports, memory adapters, autoloads, specs,
# the master gem generator, and shared context-aware helpers.
#
module Hecks
  module Generators
    module Infrastructure
      autoload :PortGenerator,          "hecks/generators/infrastructure/port_generator"
      autoload :MemoryAdapterGenerator, "hecks/generators/infrastructure/memory_adapter_generator"
      autoload :AutoloadGenerator,      "hecks/generators/infrastructure/autoload_generator"
      autoload :SpecGenerator,          "hecks/generators/infrastructure/spec_generator"
      autoload :SpecHelpers,            "hecks/generators/infrastructure/spec_helpers"
      autoload :DomainGemGenerator,     "hecks/generators/infrastructure/domain_gem_generator"
    end
  end
end
