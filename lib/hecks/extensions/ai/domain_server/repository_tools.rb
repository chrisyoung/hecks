# Hecks::MCP::DomainServer::RepositoryTools
#
# Registers MCP tools for aggregate CRUD operations: Find, All, Count.
# Each aggregate gets three tools for basic repository access.
#
# Mixed into DomainServer — expects @server, @domain, @mod, plus
# helper method serialize_aggregate.
#
module Hecks
  module MCP
    class DomainServer
      module RepositoryTools
        private

        def register_repository_tools
          @domain.aggregates.each do |agg|
            agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
            name = agg.name
            klass = agg_class

            @server.define_tool(
              name: "Find#{name}",
              description: "Find a #{name} by ID",
              input_schema: { type: "object", properties: { id: { type: "string" } }, required: ["id"] }
            ) do |args|
              result = klass.find(args["id"])
              result ? serialize_aggregate(result) : "Not found"
            end

            @server.define_tool(
              name: "All#{name}s",
              description: "List all #{name}s",
              input_schema: { type: "object", properties: {} }
            ) do |_|
              klass.all.map { |r| serialize_aggregate(r) }.join("\n")
            end

            @server.define_tool(
              name: "Count#{name}s",
              description: "Count #{name}s",
              input_schema: { type: "object", properties: {} }
            ) do |_|
              klass.count.to_s
            end
          end
        end
      end
    end
  end
end
