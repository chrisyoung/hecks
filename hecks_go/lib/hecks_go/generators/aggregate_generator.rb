# HecksGo::AggregateGenerator
#
# Generates a Go struct for an aggregate root with typed fields,
# a Validate() method from DSL validations, and lifecycle predicates.
#
#   gen = AggregateGenerator.new(agg, package: "domain")
#   gen.generate  # => Go source string
#
module HecksGo
  class AggregateGenerator
    include GoUtils

    def initialize(aggregate, package:)
      @agg = aggregate
      @package = package
      @user_attrs = @agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""

      imports = ["\"time\"", "\"github.com/google/uuid\""]
      imports << "\"encoding/json\"" if GoUtils.needs_json_import?(@user_attrs)
      lines << "import ("
      imports.each { |i| lines << "\t#{i}" }
      lines << ")"
      lines << ""

      # Struct
      lines << "type #{@agg.name} struct {"
      lines << "\tID        string    `json:\"id\"`"
      @user_attrs.each do |attr|
        go_t = GoUtils.go_type(attr)
        field = GoUtils.pascal_case(attr.name)
        tag = GoUtils.json_tag(attr.name)
        lines << "\t#{field} #{go_t} `json:\"#{tag}\"`"
      end
      lines << "\tCreatedAt time.Time `json:\"created_at\"`"
      lines << "\tUpdatedAt time.Time `json:\"updated_at\"`"
      lines << "}"
      lines << ""

      # Constructor
      lines << "func New#{@agg.name}(#{constructor_params}) *#{@agg.name} {"
      lines << "\ta := &#{@agg.name}{"
      lines << "\t\tID:        uuid.New().String(),"
      @user_attrs.each do |attr|
        field = GoUtils.pascal_case(attr.name)
        param = GoUtils.camel_case(attr.name)
        lines << "\t\t#{field}: #{param},"
      end
      lines << "\t\tCreatedAt: time.Now(),"
      lines << "\t\tUpdatedAt: time.Now(),"
      lines << "\t}"
      lines << "\treturn a"
      lines << "}"
      lines << ""

      # Validate
      lines.concat(validate_method)
      # Lifecycle predicates are in the lifecycle file if present

      lines.join("\n") + "\n"
    end

    private

    def constructor_params
      @user_attrs.map do |attr|
        "#{GoUtils.camel_case(attr.name)} #{GoUtils.go_type(attr)}"
      end.join(", ")
    end

    def validate_method
      lines = []
      lines << "func (a *#{@agg.name}) Validate() error {"
      @agg.validations.each do |v|
        field = GoUtils.pascal_case(v.field)
        if v.rules[:presence]
          lines << "\tif a.#{field} == \"\" {"
          lines << "\t\treturn &ValidationError{Field: \"#{v.field}\", Message: \"#{v.field} can't be blank\"}"
          lines << "\t}"
        end
      end
      @agg.invariants.each do |inv|
        lines << "\t// invariant: #{inv.message}"
      end
      lines << "\treturn nil"
      lines << "}"
      lines
    end
  end
end
