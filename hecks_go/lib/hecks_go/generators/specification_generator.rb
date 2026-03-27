# HecksGo::SpecificationGenerator
#
# Generates Go specification structs with SatisfiedBy method.
# Specifications are composable predicates for business rules.
#
module HecksGo
  class SpecificationGenerator
    include GoUtils

    def initialize(spec, aggregate_name:, package:)
      @spec = spec
      @agg = aggregate_name
      @package = package
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""
      lines << "type #{@spec.name} struct{}"
      lines << ""
      lines << "func (s #{@spec.name}) SatisfiedBy(#{GoUtils.camel_case(@agg)} *#{@agg}) bool {"
      lines << "\t// TODO: translate DSL block to Go predicate"
      lines << "\treturn true"
      lines << "}"

      lines.join("\n") + "\n"
    end
  end
end
