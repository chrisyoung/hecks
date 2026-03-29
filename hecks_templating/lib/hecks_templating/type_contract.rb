# = HecksTemplating::TypeContract
#
# Single source of truth for mapping domain IR types to target-specific
# representations. Every generator (Go, SQL, JSON Schema, OpenAPI)
# consumes this contract instead of maintaining its own type map.
#
#   HecksTemplating::TypeContract.go("Integer")      # => "int64"
#   HecksTemplating::TypeContract.sql("Integer")     # => "INTEGER"
#   HecksTemplating::TypeContract.json("Integer")    # => "integer"
#   HecksTemplating::TypeContract.openapi("Integer") # => "integer"
#
module HecksTemplating
  module TypeContract
    TYPES = {
      "String"   => { go: "string",          sql: "VARCHAR(255)", json: "string",  openapi: "string"  },
      "Integer"  => { go: "int64",           sql: "INTEGER",      json: "integer", openapi: "integer" },
      "Float"    => { go: "float64",         sql: "REAL",         json: "number",  openapi: "number"  },
      "Boolean"  => { go: "bool",            sql: "BOOLEAN",      json: "boolean", openapi: "boolean" },
      "Date"     => { go: "time.Time",       sql: "DATE",         json: "string",  openapi: "string"  },
      "DateTime" => { go: "time.Time",       sql: "VARCHAR(255)", json: "string",  openapi: "string"  },
      "JSON"     => { go: "json.RawMessage", sql: "TEXT",         json: "object",  openapi: "object"  },
    }.freeze

    def self.go(type)      = TYPES.dig(type.to_s, :go) || "string"
    def self.sql(type)     = TYPES.dig(type.to_s, :sql) || "TEXT"
    def self.json(type)    = TYPES.dig(type.to_s, :json) || "string"
    def self.openapi(type) = TYPES.dig(type.to_s, :openapi) || "string"

    # Go-specific helpers derived from the contract

    def self.go_zero_value(go_type)
      case go_type
      when "string"          then '""'
      when "int64"           then "0"
      when "float64"         then "0.0"
      when "bool"            then "false"
      when "time.Time"       then "time.Time{}"
      when "json.RawMessage" then "nil"
      else "nil"
      end
    end

    def self.go_needs_time?(attrs)
      attrs.any? { |a| %w[Date DateTime].include?(a.type.to_s) }
    end

    def self.go_needs_json?(attrs)
      attrs.any? { |a| a.type.to_s == "JSON" }
    end

    # Format a Ruby literal value as a Go literal for the given Go type.
    # Used by query and specification generators to produce correct
    # typed comparisons in generated Go code.
    #
    # @param value [String, Numeric] the Ruby value
    # @param go_type [String] the Go type string (e.g., "int64", "string")
    # @return [String] a Go literal (e.g., '"hello"', '42', 'true')
    def self.format_go_literal(value, go_type)
      case go_type
      when "int64", "float64"
        value.to_s.gsub(/_/, "")
      when "bool"
        value.to_s.downcase == "true" ? "true" : "false"
      when "time.Time"
        "parseDate(\"#{value}\")"
      else
        "\"#{value}\""
      end
    end
  end
end
