# = Hecks::NamingHelpers
#
# Mixin that provides naming convention helpers as regular methods.
# Include in any class or module — methods propagate through include
# chains, so mixins-into-mixins work correctly.
#
#   include Hecks::NamingHelpers
#   domain_module_name("Pizzas")     # => "PizzasDomain"
#   domain_aggregate_slug("Pizza")   # => "pizzas"
#   domain_command_method("CreatePizza", "Pizza") # => :create
#
module Hecks
  module NamingHelpers
    private

    def domain_module_name(name)
      Hecks::Templating::Names.domain_module_name(name)
    end

    def domain_gem_name(name)
      Hecks::Templating::Names.domain_gem_name(name)
    end

    def domain_constant_name(name)
      Hecks::Templating::Names.domain_constant_name(name)
    end

    def domain_snake_name(name)
      Hecks::Templating::Names.domain_snake_name(name)
    end

    def domain_aggregate_slug(name)
      Hecks::Templating::Names.domain_aggregate_slug(name)
    end

    def domain_slug(name)
      Hecks::Templating::Names.domain_slug(name)
    end

    def domain_command_name(verb, aggregate_name)
      Hecks::Templating::Names.domain_command_name(verb, aggregate_name)
    end

    def domain_referenced_name(foreign_key)
      Hecks::Templating::Names.domain_referenced_name(foreign_key)
    end

    def domain_command_method(cmd_name, agg_name)
      Hecks::Templating::Names.domain_command_method(cmd_name, agg_name)
    end

    def domain_route_path(domain_name, aggregate_name)
      Hecks::Templating::Names.domain_route_path(domain_name, aggregate_name)
    end

    def domain_output_dir(domain_name)
      Hecks::Templating::Names.domain_output_dir(domain_name)
    end
  end
end
