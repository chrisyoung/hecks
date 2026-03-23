# Hecks::Generators::ContextAware
#
# Mixin for generators that need to handle optional bounded context nesting.
# Provides helpers for module wrapping, file path prefixes, and indentation
# adjustments when generating code inside a context module.
#
# Usage in a generator:
#
#   class MyGenerator
#     include ContextAware
#
#     def initialize(thing, domain_module:, context_module: nil)
#       @domain_module = domain_module
#       @context_module = context_module
#     end
#
#     def generate
#       lines = []
#       lines.concat(module_open_lines)
#       lines << "#{indent}class MyClass"
#       lines << "#{indent}end"
#       lines.concat(module_close_lines)
#       lines.join("\n") + "\n"
#     end
#   end
#
module Hecks
  module Generators
    module ContextAware
      # The full module name: "PizzasDomain::Ordering" or just "PizzasDomain"
      def full_module_name
        if @context_module
          "#{@domain_module}::#{@context_module}"
        else
          @domain_module
        end
      end

      # Opening module lines
      def module_open_lines
        if @context_module
          ["module #{@domain_module}", "  module #{@context_module}"]
        else
          ["module #{@domain_module}"]
        end
      end

      # Closing module lines
      def module_close_lines
        if @context_module
          ["  end", "end"]
        else
          ["end"]
        end
      end

      # Base indent inside the module nesting
      def indent
        @context_module ? "    " : "  "
      end

      # One level deeper
      def indent2
        indent + "  "
      end

      # Two levels deeper
      def indent3
        indent + "    "
      end

      # Path prefix for files: "ordering/" or ""
      def context_path_prefix
        @context_module ? "#{Hecks::Utils.underscore(@context_module)}/" : ""
      end
    end
  end
end
