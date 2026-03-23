# Hecks::HTTP::JsonSchemaGenerator
#
# Generates JSON Schema files from a domain. One schema per command,
# plus one per aggregate for the response shape.
#
module Hecks
  module HTTP
    class JsonSchemaGenerator
      def initialize(domain)
        @domain = domain
      end

      def generate
        schemas = {}
        @domain.aggregates.each do |agg|
          schemas["#{agg.name}"] = aggregate_schema(agg)
          agg.commands.each do |cmd|
            schemas[cmd.name] = command_schema(cmd)
          end
        end
        schemas
      end

      private

      def aggregate_schema(agg)
        props = { id: { type: "string", format: "uuid" } }
        agg.attributes.reject(&:list?).each do |attr|
          props[attr.name] = property(attr)
        end
        props[:created_at] = { type: "string", format: "date-time" }
        props[:updated_at] = { type: "string", format: "date-time" }

        {
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          title: agg.name,
          type: "object",
          properties: props
        }
      end

      def command_schema(cmd)
        props = {}
        required = []
        cmd.attributes.each do |attr|
          props[attr.name] = property(attr)
          required << attr.name.to_s
        end

        {
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          title: cmd.name,
          type: "object",
          properties: props,
          required: required
        }
      end

      def property(attr)
        if attr.json?
          { type: ["object", "array"] }
        elsif attr.reference?
          { type: "string", format: "uuid", description: "Reference to #{attr.type}" }
        else
          case attr.ruby_type
          when "Integer" then { type: "integer" }
          when "Float" then { type: "number" }
          else { type: "string" }
          end
        end
      end
    end
  end
end
