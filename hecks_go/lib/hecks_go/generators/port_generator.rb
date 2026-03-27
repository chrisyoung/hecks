# HecksGo::PortGenerator
#
# Generates a Go interface for a repository port. Ports are Go's native
# abstraction — compile-time enforcement, not runtime NotImplementedError.
#
module HecksGo
  class PortGenerator
    include GoUtils

    def initialize(aggregate, package:)
      @agg = aggregate
      @package = package
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""
      lines << "type #{@agg.name}Repository interface {"
      lines << "\tFind(id string) (*#{@agg.name}, error)"
      lines << "\tSave(#{GoUtils.camel_case(@agg.name)} *#{@agg.name}) error"
      lines << "\tAll() ([]*#{@agg.name}, error)"
      lines << "\tDelete(id string) error"
      lines << "\tCount() (int, error)"
      lines << "}"

      lines.join("\n") + "\n"
    end
  end
end
