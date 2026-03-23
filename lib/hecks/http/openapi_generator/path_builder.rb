# Hecks::HTTP::OpenapiGenerator::PathBuilder
#
# Builds OpenAPI path entries from domain aggregates. Each aggregate
# gets CRUD paths and query paths; a shared /events SSE path is added.
#
# Mixed into OpenapiGenerator to keep path logic separate from schemas.
#
module Hecks
  module HTTP
    class OpenapiGenerator
      module PathBuilder
        private

        def build_paths
          paths = {}
          @domain.aggregates.each do |agg|
            slug = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(agg.name)) + "s"
            paths.merge!(crud_paths(agg, slug))
            paths.merge!(query_paths(agg, slug))
          end
          paths["/events"] = events_path
          paths
        end

        def crud_paths(agg, slug)
          name = agg.name
          paths = {}

          paths["/#{slug}"] = {
            get: { summary: "List all #{name}s", responses: ok_array(name) },
            post: post_path(agg, slug)
          }.compact

          paths["/#{slug}/{id}"] = {
            get: { summary: "Find #{name} by ID", parameters: [id_param], responses: ok_object(name) },
            patch: patch_path(agg),
            delete: { summary: "Delete #{name}", parameters: [id_param], responses: ok_message }
          }.compact

          paths
        end

        def post_path(agg, slug)
          cmd = agg.commands.find { |c| c.name.start_with?("Create") }
          return nil unless cmd
          {
            summary: cmd.name,
            requestBody: request_body(cmd),
            responses: ok_object(agg.name)
          }
        end

        def patch_path(agg)
          cmd = agg.commands.find { |c| c.name.start_with?("Update") }
          return nil unless cmd
          {
            summary: cmd.name,
            parameters: [id_param],
            requestBody: request_body(cmd),
            responses: ok_object(agg.name)
          }
        end

        def query_paths(agg, slug)
          paths = {}
          agg.queries.each do |query|
            qn = Hecks::Utils.underscore(query.name)
            params = query.block.parameters.map do |_, name|
              { name: name.to_s, in: "query", schema: { type: "string" }, required: true }
            end
            paths["/#{slug}/#{qn}"] = {
              get: {
                summary: "#{agg.name}.#{qn}",
                parameters: params.empty? ? nil : params,
                responses: ok_array(agg.name)
              }.compact
            }
          end
          paths
        end

        def events_path
          { get: { summary: "SSE event stream", responses: { "200" => { description: "Server-Sent Events stream" } } } }
        end
      end
    end
  end
end
