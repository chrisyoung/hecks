# Hecks::MCP::DomainServer::QueryTools
#
# Registers MCP tools for domain queries. Each query on each aggregate
# becomes a callable tool. Handles both parameterized and zero-arg queries.
#
# Mixed into DomainServer — expects @server, @domain, @mod, plus
# helper method serialize_aggregate.
#
module Hecks
  module MCP
    class DomainServer
      module QueryTools
        private

        def register_query_tools
          @domain.aggregates.each do |agg|
            agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
            agg.queries.each do |query|
              register_query(agg, agg_class, query)
            end
          end
        end

        def register_query(agg, agg_class, query)
          method_name = Hecks::Utils.underscore(query.name).to_sym
          params = query.block.parameters
          klass = agg_class

          if params.empty?
            @server.define_tool(
              name: "#{agg.name}_#{method_name}",
              description: "#{agg.name}.#{method_name} — lookup",
              input_schema: { type: "object", properties: {} }
            ) do |_|
              results = klass.send(method_name)
              results.respond_to?(:map) ? results.map { |r| serialize_aggregate(r) }.join("\n") : results.to_s
            end
          else
            props = params.each_with_object({}) { |(_, name), h| h[name.to_s] = { type: "string" } }
            @server.define_tool(
              name: "#{agg.name}_#{method_name}",
              description: "#{agg.name}.#{method_name} — lookup",
              input_schema: { type: "object", properties: props, required: props.keys }
            ) do |args|
              values = params.map { |_, name| args[name.to_s] }
              results = klass.send(method_name, *values)
              results.respond_to?(:map) ? results.map { |r| serialize_aggregate(r) }.join("\n") : results.to_s
            end
          end
        end
      end
    end
  end
end
