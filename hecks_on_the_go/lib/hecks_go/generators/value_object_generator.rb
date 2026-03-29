# HecksOnTheGo::ValueObjectGenerator
#
# Generates a Go struct for a value object with a constructor that
# validates invariants. Value objects are plain structs — immutability
# is by convention (no pointer receiver mutators).
#
module HecksOnTheGo
  class ValueObjectGenerator
    include GoUtils

    def initialize(value_object, package:)
      @vo = value_object
      @package = package
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""

      needs_fmt = !@vo.invariants.empty?
      if needs_fmt
        lines << "import \"fmt\""
        lines << ""
      end

      # Struct
      lines << "type #{@vo.name} struct {"
      @vo.attributes.each do |attr|
        field = GoUtils.pascal_case(attr.name)
        go_t = GoUtils.go_type(attr)
        tag = GoUtils.json_tag(attr.name)
        lines << "\t#{field} #{go_t} `json:\"#{tag}\"`"
      end
      lines << "}"
      lines << ""

      # Constructor with invariant checks
      params = @vo.attributes.map { |a| "#{GoUtils.camel_case(a.name)} #{GoUtils.go_type(a)}" }.join(", ")
      lines << "func New#{@vo.name}(#{params}) (#{@vo.name}, error) {"
      lines << "\tv := #{@vo.name}{"
      @vo.attributes.each do |attr|
        lines << "\t\t#{GoUtils.pascal_case(attr.name)}: #{GoUtils.camel_case(attr.name)},"
      end
      lines << "\t}"

      @vo.invariants.each do |inv|
        # Generate a basic check from the invariant message
        lines << "\t// #{inv.message}"
        # Try to extract field and condition from the message
        if inv.message =~ /(\w+) must be positive/
          field = GoUtils.pascal_case($1)
          lines << "\tif v.#{field} <= 0 {"
          lines << "\t\treturn #{@vo.name}{}, fmt.Errorf(\"#{inv.message}\")"
          lines << "\t}"
        end
      end

      lines << "\treturn v, nil"
      lines << "}"

      lines.join("\n") + "\n"
    end
  end
end
