# HecksGo::GoUtils
#
# Naming and type mapping utilities for Go code generation.
# Converts Ruby DSL types to Go types, snake_case to camelCase, etc.
#
module HecksGo
  module GoUtils
    module_function

    TYPE_MAP = {
      "String"   => "string",
      "Integer"  => "int64",
      "Float"    => "float64",
      "Boolean"  => "bool",
      "Date"     => "time.Time",
      "DateTime" => "time.Time",
      "JSON"     => "json.RawMessage",
    }.freeze

    def go_type(attr)
      if attr.list?
        "[]#{pascal_case(attr.type.to_s)}"
      elsif attr.reference?
        "string" # UUID reference
      else
        TYPE_MAP[attr.type.to_s] || "string"
      end
    end

    def pascal_case(str)
      str.to_s.split("_").map(&:capitalize).join
    end

    def camel_case(str)
      parts = str.to_s.split("_")
      parts.first + parts[1..].map(&:capitalize).join
    end

    def snake_case(str)
      Hecks::Utils.underscore(str.to_s)
    end

    def go_package(name)
      snake_case(name).downcase
    end

    def json_tag(name)
      snake_case(name)
    end

    def go_zero_value(type_str)
      case type_str
      when "string" then '""'
      when "int64" then "0"
      when "float64" then "0.0"
      when "bool" then "false"
      when "time.Time" then "time.Time{}"
      else "nil"
      end
    end

    def needs_time_import?(attrs)
      attrs.any? { |a| %w[Date DateTime].include?(a.type.to_s) }
    end

    def needs_json_import?(attrs)
      attrs.any? { |a| a.type.to_s == "JSON" }
    end
  end
end
