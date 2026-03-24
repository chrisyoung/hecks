# Hecks::Configuration::SqlSetup
#
# Generates and evals SQL adapter classes for each aggregate at boot time.
# These adapters wrap Sequel datasets and implement the repository port.
#
module Hecks
  class Configuration
    module SqlSetup
      private

      def generate_adapters(domain_obj)
        domain_obj.aggregates.each do |agg|
          gen = Generators::SQL::SqlAdapterGenerator.new(
            agg, domain_module: domain_obj.module_name + "Domain"
          )
          eval(gen.generate, TOPLEVEL_BINDING, "(hecks:sql:#{agg.name})")
        end
      end
    end
  end
end
