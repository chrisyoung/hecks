# Hecks::HTTP::OpenapiGenerator::ResponseHelpers
#
# Shared OpenAPI response/parameter helpers used by both PathBuilder
# and SchemaBuilder. Provides ok_array, ok_object, ok_message,
# id_param, and request_body builders.
#
# Mixed into OpenapiGenerator for use across all builder modules.
#
module Hecks
  module HTTP
    class OpenapiGenerator
      module ResponseHelpers
        private

        def request_body(cmd)
          props = {}
          cmd.attributes.each do |attr|
            props[attr.name] = { type: openapi_type(attr) }
          end
          { content: { "application/json" => { schema: { type: "object", properties: props } } } }
        end

        def id_param
          { name: "id", in: "path", required: true, schema: { type: "string" } }
        end

        def ok_array(name)
          { "200" => { description: "Array of #{name}s", content: { "application/json" => { schema: { type: "array", items: { "$ref" => "#/components/schemas/#{name}" } } } } } }
        end

        def ok_object(name)
          { "200" => { description: name, content: { "application/json" => { schema: { "$ref" => "#/components/schemas/#{name}" } } } } }
        end

        def ok_message
          { "200" => { description: "Success" } }
        end
      end
    end
  end
end
