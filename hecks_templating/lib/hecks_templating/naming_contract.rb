# = Hecks::Templating::Names
#
# Single source of truth for all naming conventions in Hecks.
# Use as module methods or mix in for shorter calls:
#
#   include Hecks::Templating::Names
#   domain_module_name("Pizzas")   # => "PizzasDomain"
#   aggregate_slug("Pizza")        # => "pizzas"
#   go_binary_name("Pizzas")       # => "pizzas_server"
#
module Hecks
  module Templating
    module Names
      module_function

      # "Pizzas" → "PizzasDomain"
      def domain_module_name(name)
        Hecks::Utils.sanitize_constant(name) + "Domain"
      end
      # Alias for backward compat with existing callers
      def self.domain_module(name) = domain_module_name(name)

      # "Pizzas" → "pizzas_domain"
      def domain_gem_name(name)
        Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(name)) + "_domain"
      end
      def self.gem_name(name) = domain_gem_name(name)

      # "pizza order" → "PizzaOrder"
      def constant_name(name)
        Hecks::Utils.sanitize_constant(name)
      end

      # "GovernancePolicy" → "governance_policy"
      def snake_name(name)
        Hecks::Utils.underscore(name)
      end
      def self.snake(name) = snake_name(name)

      # "Pizza" → "pizzas"
      def aggregate_slug(name)
        s = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(name))
        s.end_with?("s") ? s : s + "s"
      end

      # "Pizza" → "pizzas"
      def table_name(name)
        aggregate_slug(name)
      end

      # "Blog" → "blog"
      def domain_slug(name)
        Hecks::Utils.underscore(name)
      end

      # "Pizzas" → "pizzas_server"
      def go_binary_name(name)
        domain_slug(name) + "_server"
      end
      def self.binary_name(name) = go_binary_name(name)

      # ("create", "Pizza") → "CreatePizza"
      def infer_command_name(verb, aggregate_name)
        parts = verb.to_s.split("_")
        if parts.size == 1
          parts.first.capitalize + Hecks::Utils.sanitize_constant(aggregate_name)
        else
          parts.map(&:capitalize).join
        end
      end
      def self.command_name(verb, agg) = infer_command_name(verb, agg)

      # "CreatePizza" on "Pizza" → :create
      def derive_method_name(cmd_name, agg_name)
        Hecks::Utils.underscore(cmd_name)
          .sub(/_#{Hecks::Utils.underscore(agg_name)}$/, "").to_sym
      end
      def self.method_name(cmd, agg) = derive_method_name(cmd, agg)

      # ("Blog", "Post") → "/blog/posts"
      def route_path(domain_name, aggregate_name)
        "/#{domain_slug(domain_name)}/#{aggregate_slug(aggregate_name)}"
      end

      # ("Pizzas", :go) → "pizzas_static_go"
      def output_dir_name(domain_name, target: :ruby)
        base = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(domain_name))
        case target
        when :go then "#{base}_static_go"
        when :static then "#{base}_domain"
        else "#{base}_domain"
        end
      end
      def self.output_dir(name, target: :ruby) = output_dir_name(name, target: target)
    end
  end
end
