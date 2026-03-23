# Hecks::Generators::Infrastructure
#
# Parent module for infrastructure generators. Autoloads generators for
# repository ports, memory adapters, autoload entry points, RSpec specs,
# and the top-level domain gem generator (DomainGemGenerator). Part of
# the Generators layer, consumed by DomainGemGenerator and SourceBuilder.
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
