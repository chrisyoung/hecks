# HecksGo::CommandGenerator
#
# Generates a Go struct for a command with an Execute method.
# Create commands build a new aggregate; update commands look up
# an existing one by ID and merge changed attributes.
#
module HecksGo
  class CommandGenerator
    include GoUtils

    def initialize(command, aggregate:, event:, package:)
      @cmd = command
      @agg = aggregate
      @event = event
      @package = package
      agg_snake = GoUtils.snake_case(@agg.name)
      @self_id = @cmd.attributes.find { |a| a.name.to_s == "#{agg_snake}_id" }
      @is_create = @self_id.nil?
    end

    def generate
      lines = []
      lines << "package #{@package}"
      lines << ""
      imports = ["\"time\""]
      imports << "\"fmt\"" unless @is_create
      lines << "import ("
      imports.each { |i| lines << "\t#{i}" }
      lines << ")"
      lines << ""

      # Command struct
      lines << "type #{@cmd.name} struct {"
      @cmd.attributes.each do |attr|
        field = GoUtils.pascal_case(attr.name)
        go_t = GoUtils.go_type(attr)
        tag = GoUtils.json_tag(attr.name)
        lines << "\t#{field} #{go_t} `json:\"#{tag}\"`"
      end
      lines << "}"
      lines << ""

      lines << "func (c #{@cmd.name}) CommandName() string { return \"#{@cmd.name}\" }"
      lines << ""

      # Execute method
      lines << "func (c #{@cmd.name}) Execute(repo #{@agg.name}Repository) (*#{@agg.name}, *#{@event.name}, error) {"
      if @is_create
        lines.concat(create_body)
      else
        lines.concat(update_body)
      end
      lines << "}"

      lines.join("\n") + "\n"
    end

    private

    def create_body
      agg_attrs = @agg.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
      args = @cmd.attributes.map { |a| "c.#{GoUtils.pascal_case(a.name)}" }
      # Map command attrs to constructor params
      constructor_args = agg_attrs.map do |a|
        cmd_attr = @cmd.attributes.find { |c| c.name == a.name }
        cmd_attr ? "c.#{GoUtils.pascal_case(a.name)}" : GoUtils.go_zero_value(GoUtils.go_type(a))
      end.join(", ")

      lines = []
      lines << "\tagg := New#{@agg.name}(#{constructor_args})"
      lines << "\tif err := agg.Validate(); err != nil {"
      lines << "\t\treturn nil, nil, err"
      lines << "\t}"
      lines << "\tif err := repo.Save(agg); err != nil {"
      lines << "\t\treturn nil, nil, err"
      lines << "\t}"
      lines << "\tevent := #{@event.name}{"
      lines << "\t\tAggregateID: agg.ID,"
      @cmd.attributes.each do |a|
        lines << "\t\t#{GoUtils.pascal_case(a.name)}: c.#{GoUtils.pascal_case(a.name)},"
      end
      lines << "\t\tOccurredAt: time.Now(),"
      lines << "\t}"
      lines << "\treturn agg, &event, nil"
      lines
    end

    def update_body
      lines = []
      lines << "\texisting, err := repo.Find(c.#{GoUtils.pascal_case(@self_id.name)})"
      lines << "\tif err != nil {"
      lines << "\t\treturn nil, nil, err"
      lines << "\t}"
      lines << "\tif existing == nil {"
      lines << "\t\treturn nil, nil, fmt.Errorf(\"#{@agg.name} not found: %s\", c.#{GoUtils.pascal_case(@self_id.name)})"
      lines << "\t}"
      # Apply changes — only set fields that exist on the aggregate
      agg_attr_names = @agg.attributes.map { |a| a.name.to_s }
      @cmd.attributes.each do |a|
        next if a == @self_id
        if agg_attr_names.include?(a.name.to_s)
          lines << "\texisting.#{GoUtils.pascal_case(a.name)} = c.#{GoUtils.pascal_case(a.name)}"
        end
      end
      lines << "\texisting.UpdatedAt = time.Now()"
      lines << "\tif err := existing.Validate(); err != nil {"
      lines << "\t\treturn nil, nil, err"
      lines << "\t}"
      lines << "\tif err := repo.Save(existing); err != nil {"
      lines << "\t\treturn nil, nil, err"
      lines << "\t}"
      lines << "\tevent := #{@event.name}{"
      lines << "\t\tAggregateID: existing.ID,"
      @cmd.attributes.each do |a|
        lines << "\t\t#{GoUtils.pascal_case(a.name)}: c.#{GoUtils.pascal_case(a.name)},"
      end
      lines << "\t\tOccurredAt: time.Now(),"
      lines << "\t}"
      lines << "\treturn existing, &event, nil"
      lines
    end
  end
end
