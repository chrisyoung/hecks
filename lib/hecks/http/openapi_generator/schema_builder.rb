# Hecks::HTTP::OpenapiGenerator::SchemaBuilder
#
# Builds OpenAPI component schemas from domain aggregates. Maps DSL
# attribute types to OpenAPI types (integer, number, object, string).
#
# Mixed into OpenapiGenerator to keep schema logic separate from paths.
#
module Hecks
  module HTTP
    class OpenapiGenerator
      module SchemaBuilder
        private

        def build_schemas
          schemas = {}
          @domain.aggregates.each do |agg|
            props = { id: { type: "string" } }
            agg.attributes.reject(&:list?).each do |attr|
              props[attr.name] = { type: openapi_type(attr) }
            end
            props[:created_at] = { type: "string", format: "date-time" }
            props[:updated_at] = { type: "string", format: "date-time" }
            schemas[agg.name] = { type: "object", properties: props }
          end
          schemas
        end

        def openapi_type(attr)
          case attr.ruby_type
          when "Integer" then "integer"
          when "Float" then "number"
          when "JSON" then "object"
          else "string"
          end
        end
      end
    end
  end
end
