# Hecks::DSL::AggregateBuilder::ImplicitSyntax
#
# method_missing-based implicit DSL support extracted from AggregateBuilder.
# Enables shorthand syntax like `title String` and `Topping do ... end`.
#
module Hecks
  module DSL
    class AggregateBuilder
      module ImplicitSyntax
        # Implicit DSL dispatch:
        # - PascalCase + block → value_object
        # - snake_case + block → command (name inferred)
        # - name Type → attribute
        def method_missing(name, *args, **kwargs, &block)
          name_s = name.to_s
          if name_s =~ /\A[A-Z]/ && block_given?
            value_object(name_s, &block)
          elsif block_given?
            cmd_name = infer_command_name(name_s)
            command(cmd_name, &block)
          elsif args.first.is_a?(Class) || (args.first.is_a?(String) && args.first =~ /\A[A-Z]/)
            attribute(name, args.first, **kwargs)
          elsif args.first.is_a?(Hash) && (args.first[:list] || args.first[:reference])
            attribute(name, args.first, **kwargs)
          else
            super
          end
        end

        def respond_to_missing?(name, include_private = false)
          true
        end

        private

        # Infer PascalCase command name from snake_case method.
        # Single verb → verb + aggregate name (create → CreatePizza)
        # Multi-word → PascalCase as-is (add_topping → AddTopping)
        def infer_command_name(snake)
          parts = snake.split("_")
          if parts.size == 1
            parts.first.capitalize + @name
          else
            parts.map(&:capitalize).join
          end
        end
      end
    end
  end
end
