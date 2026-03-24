# Hecks::Generators::Domain::SpecificationGenerator
#
# Generates specification classes nested under Aggregate::Specifications.
# Extracts the DSL block source and emits it as the body of a satisfied_by?
# method. The Hecks::Specification mixin is injected at load time by
# SourceBuilder (eval) or by const_missing (file-based gems). Part of
# Generators::Domain, consumed by DomainGemGenerator and SourceBuilder.
#
#   gen = SpecificationGenerator.new(spec, domain_module: "BankingDomain", aggregate_name: "Loan")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class SpecificationGenerator

      def initialize(specification, domain_module:, aggregate_name:)
        @specification = specification
        @domain_module = domain_module
        @aggregate_name = aggregate_name
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Specifications"
        lines << "      class #{@specification.name}"
        lines << "        def satisfied_by?#{call_params}"
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
        params = block_params
        return "(object)" if params.empty?
        "(#{params.join(", ")})"
      end

      def block_params
        @specification.block.parameters.map { |_, name| name.to_s }
      end

      def call_body
        Hecks::Utils.block_source(@specification.block)
      end
    end
    end
  end
end
