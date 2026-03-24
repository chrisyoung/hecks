# Hecks::Generators::Domain::SubscriberGenerator
#
# Generates subscriber classes nested under Aggregate::Subscribers.
# Each subscriber declares EVENT and ASYNC constants, and a call(event)
# method whose body is extracted from the DSL block. Part of
# Generators::Domain, consumed by DomainGemGenerator and InMemoryLoader.
#
#   gen = SubscriberGenerator.new(sub, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class SubscriberGenerator

      def initialize(subscriber, domain_module:, aggregate_name:)
        @subscriber = subscriber
        @domain_module = domain_module
        @aggregate_name = aggregate_name
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Subscribers"
        lines << "      class #{@subscriber.name}"
        lines << "        EVENT = \"#{@subscriber.event_name}\""
        lines << "        ASYNC = #{@subscriber.async}"
        lines << ""
        lines << "        def self.event = EVENT"
        lines << "        def self.async = ASYNC"
        lines << ""
        lines << "        def call#{call_params}"
        lines << "          #{call_body}"
        lines << "        end"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def call_params
        params = @subscriber.block&.parameters&.map { |_, name| name.to_s } || []
        return "" if params.empty?
        "(#{params.join(", ")})"
      end

      def call_body
        Hecks::Utils.block_source(@subscriber.block)
      end
    end
    end
  end
end
