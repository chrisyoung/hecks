# Hecks::Generators::Domain::PolicyGenerator
#
# Generates policy classes that declare reactive rules binding events to
# commands. Policies enable cross-gem communication via the event bus.
#
#   gen = PolicyGenerator.new(policy, domain_module: "PizzasDomain", aggregate_name: "Order")
#   gen.generate  # => "module PizzasDomain\n  class Order\n    module Policies\n  ..."
#
module Hecks
  module Generators
    module Domain
    class PolicyGenerator

      def initialize(policy, domain_module:, aggregate_name:)
        @policy = policy
        @domain_module = domain_module
        @aggregate_name = aggregate_name
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Policies"
        lines << "      class #{@policy.name}"
        lines << "        remove_const(:EVENT) if const_defined?(:EVENT)"
        lines << "        EVENT   = \"#{@policy.event_name}\""
        lines << "        remove_const(:TRIGGER) if const_defined?(:TRIGGER)"
        lines << "        TRIGGER = \"#{@policy.trigger_command}\""
        lines << ""
        lines << "        def self.event   = EVENT"
        lines << "        def self.trigger = TRIGGER"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end
    end
    end
  end
end
