# Hecks::Generators::Domain::PolicyGenerator
#
# Generates policy classes. Guard policies have a call(command) method.
# Reactive policies declare EVENT, TRIGGER, and ASYNC constants. Part of
# Generators::Domain, consumed by DomainGemGenerator and InMemoryLoader.
#
#   gen = PolicyGenerator.new(policy, domain_module: "PizzasDomain", aggregate_name: "Order")
#   gen.generate
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
        @policy.guard? ? generate_guard : generate_reactive
      end

      private

      def generate_guard
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Policies"
        lines << "      class #{@policy.name}"
        lines << "        def call#{call_params}"
        lines << "          #{call_body}"
        lines << "        end"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      def generate_reactive
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Policies"
        lines << "      class #{@policy.name}"
        lines << "        def self.event   = \"#{@policy.event_name}\""
        lines << "        def self.trigger = \"#{@policy.trigger_command}\""
        lines << "        def self.async   = #{@policy.async}"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      def call_params
        params = @policy.block&.parameters&.map { |_, name| name.to_s } || []
        return "" if params.empty?
        "(#{params.join(", ")})"
      end

      def call_body
        Hecks::Utils.block_source(@policy.block)
      end
    end
    end
  end
end
