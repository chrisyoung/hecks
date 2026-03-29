# = Hecks::Templating::Names
#
# Single source of truth for all naming conventions in Hecks. Every
# string transformation that maps a domain concept to a code artifact
# lives here. Used by generators, servers, CLI, and the workbench.
#
#   Hecks::Templating::Names.domain_module("Pizzas")      # => "PizzasDomain"
#   Hecks::Templating::Names.gem_name("Pizzas")            # => "pizzas_domain"
#   Hecks::Templating::Names.aggregate_slug("Pizza")       # => "pizzas"
#   Hecks::Templating::Names.table_name("Pizza")           # => "pizzas"
#   Hecks::Templating::Names.domain_slug("Blog")           # => "blog"
#   Hecks::Templating::Names.binary_name("Pizzas")         # => "pizzas_server"
#   Hecks::Templating::Names.constant_name("pizza order")  # => "PizzaOrder"
#   Hecks::Templating::Names.command_name("create", "Pizza") # => "CreatePizza"
#   Hecks::Templating::Names.route_path("Blog", "Post")    # => "/blog/posts"
#
module Hecks
  module Templating
  module Names
    # Domain module constant name.
    # "Pizzas" → "PizzasDomain"
    def self.domain_module(domain_name)
      Hecks::Utils.sanitize_constant(domain_name) + "Domain"
    end

    # Gem name for a domain.
    # "Pizzas" → "pizzas_domain"
    def self.gem_name(domain_name)
      Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(domain_name)) + "_domain"
    end

    # PascalCase constant name from any input.
    # "pizza order" → "PizzaOrder", "governance_policy" → "GovernancePolicy"
    def self.constant_name(name)
      Hecks::Utils.sanitize_constant(name)
    end

    # Snake_case version of a name.
    # "GovernancePolicy" → "governance_policy"
    def self.snake(name)
      Hecks::Utils.underscore(name)
    end

    # URL slug for an aggregate (pluralized snake_case).
    # "Pizza" → "pizzas", "GovernancePolicy" → "governance_policys"
    def self.aggregate_slug(agg_name)
      s = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(agg_name))
      s.end_with?("s") ? s : s + "s"
    end

    # Database table name for an aggregate (same as slug).
    # "Pizza" → "pizzas"
    def self.table_name(agg_name)
      aggregate_slug(agg_name)
    end

    # URL prefix for a domain in multi-domain routing.
    # "Blog" → "blog", "ModelRegistry" → "model_registry"
    def self.domain_slug(domain_name)
      Hecks::Utils.underscore(domain_name)
    end

    # Go binary name for a domain.
    # "Pizzas" → "pizzas_server"
    def self.binary_name(domain_name)
      domain_slug(domain_name) + "_server"
    end

    # Infer a PascalCase command name from a verb and aggregate.
    # ("create", "Pizza") → "CreatePizza"
    # ("add_topping", "Pizza") → "AddTopping"
    def self.command_name(verb, aggregate_name)
      parts = verb.to_s.split("_")
      if parts.size == 1
        parts.first.capitalize + Hecks::Utils.sanitize_constant(aggregate_name)
      else
        parts.map(&:capitalize).join
      end
    end

    # Derive the method name from a command name and aggregate.
    # "CreatePizza" on Pizza → :create
    # "AddTopping" on Pizza → :add_topping
    def self.method_name(command_name, aggregate_name)
      Hecks::Utils.underscore(command_name)
        .sub(/_#{Hecks::Utils.underscore(aggregate_name)}$/, "").to_sym
    end

    # Full route path for a domain + aggregate in multi-domain routing.
    # ("Blog", "Post") → "/blog/posts"
    def self.route_path(domain_name, aggregate_name)
      "/#{domain_slug(domain_name)}/#{aggregate_slug(aggregate_name)}"
    end

    # Static output directory name for a domain + target.
    # ("Pizzas", :go) → "pizzas_static_go"
    # ("Pizzas", :ruby) → "pizzas_domain"
    def self.output_dir(domain_name, target: :ruby)
      base = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(domain_name))
      case target
      when :go then "#{base}_static_go"
      when :static then "#{base}_domain"
      else "#{base}_domain"
      end
    end
  end
  end
end
