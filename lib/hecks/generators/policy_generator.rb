# Hecks::Generators::PolicyGenerator
#
# Generates policy classes that declare reactive rules binding events to
# commands. Policies enable cross-context communication via the event bus.
#
#   gen = PolicyGenerator.new(policy, domain_module: "PizzasDomain", aggregate_name: "Order")
#   gen.generate  # => "module PizzasDomain\n  class Order\n    module Policies\n  ..."
#
module Hecks
  module Generators
    class PolicyGenerator
      include ContextAware

      def initialize(policy, domain_module:, aggregate_name:, context_module: nil)
        @policy = policy
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @context_module = context_module
      end

      def generate
        lines = []
        lines.concat(module_open_lines)
        lines << "#{indent}class #{@aggregate_name}"
        lines << "#{indent}  module Policies"
        lines << "#{indent}    class #{@policy.name}"
        lines << "#{indent}      EVENT   = \"#{@policy.event_name}\""
        lines << "#{indent}      TRIGGER = \"#{@policy.trigger_command}\""
        lines << ""
        lines << "#{indent}      def self.event   = EVENT"
        lines << "#{indent}      def self.trigger = TRIGGER"
        lines << "#{indent}    end"
        lines << "#{indent}  end"
        lines << "#{indent}end"
        lines.concat(module_close_lines)
        lines.join("\n") + "\n"
      end
    end
  end
end
