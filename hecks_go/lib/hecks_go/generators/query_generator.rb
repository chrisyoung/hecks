# HecksGo::QueryGenerator
#
# Generates Go query functions. Queries filter repository results
# based on conditions defined in the DSL.
#
module HecksGo
  class QueryGenerator
    include GoUtils

    def initialize(query, aggregate:, package:, module_path:)
      @query = query
      @agg = aggregate
      @package = package
      @module_path = module_path
    end

    def generate
      safe = @agg.name
      func_name = GoUtils.pascal_case(@query.name)
      lines = []
      lines << "package #{@package}"
      lines << ""
      lines << "// #{func_name} query for #{safe}"
      lines << "// Generated from DSL query definition"
      lines << "func #{func_name}(repo #{safe}Repository) ([]*#{safe}, error) {"
      lines << "\tall, err := repo.All()"
      lines << "\tif err != nil { return nil, err }"
      lines << "\tvar results []*#{safe}"
      lines << "\tfor _, item := range all {"
      lines << "\t\t// TODO: filter logic from DSL block"
      lines << "\t\tresults = append(results, item)"
      lines << "\t}"
      lines << "\treturn results, nil"
      lines << "}"

      lines.join("\n") + "\n"
    end
  end
end
