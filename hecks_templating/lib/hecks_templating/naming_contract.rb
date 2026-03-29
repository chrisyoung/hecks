# = Hecks::Templating::Names
#
# Single source of truth for all naming conventions in Hecks.
# Include for bare method calls:
#
#   include Hecks::Templating::Names
#   domain_module_name("Pizzas")     # => "PizzasDomain"
#   aggregate_slug("Pizza")          # => "pizzas"
#   command_method_name("CreatePizza", "Pizza") # => :create
#
module Hecks
  module Templating
    module Names
      module_function

      # "Pizzas" → "PizzasDomain"
      def domain_module_name(name)
        Hecks::Utils.sanitize_constant(name) + "Domain"
      end

      # "Pizzas" → "pizzas_domain"
      def domain_gem_name(name)
        Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(name)) + "_domain"
      end

      # "pizza order" → "PizzaOrder"
      def constant_name(name)
        Hecks::Utils.sanitize_constant(name)
      end

      # "GovernancePolicy" → "governance_policy"
      def snake_name(name)
        Hecks::Utils.underscore(name)
      end

      # "Pizza" → "pizzas"
      def aggregate_slug(name)
        s = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(name))
        s.end_with?("s") ? s : s + "s"
      end

      # "Blog" → "blog"
      def domain_slug(name)
        Hecks::Utils.underscore(name)
      end

      # ("create", "Pizza") → "CreatePizza"
      def infer_command_name(verb, aggregate_name)
        parts = verb.to_s.split("_")
        if parts.size == 1
          parts.first.capitalize + Hecks::Utils.sanitize_constant(aggregate_name)
        else
          parts.map(&:capitalize).join
        end
      end

      # "post_id" → "post"
      def referenced_name(foreign_key)
        foreign_key.to_s.sub(/_id$/, "")
      end

      # "CreatePizza" on "Pizza" → :create
      def command_method_name(cmd_name, agg_name)
        Hecks::Utils.underscore(cmd_name)
          .sub(/_#{Hecks::Utils.underscore(agg_name)}$/, "").to_sym
      end

      # ("Blog", "Post") → "/blog/posts"
      def route_path(domain_name, aggregate_name)
        "/#{domain_slug(domain_name)}/#{aggregate_slug(aggregate_name)}"
      end

      # "Pizzas" → "pizzas_domain"
      def output_dir_name(domain_name)
        Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(domain_name)) + "_domain"
      end
    end
  end
end
