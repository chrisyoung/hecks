# Hecks::MCP::DomainServer::CommandTools
#
# Registers MCP tools for domain commands. Each command on each aggregate
# becomes a callable tool with typed input schema.
#
# Mixed into DomainServer — expects @server, @domain, @mod, plus
# helper methods derive_method_name, json_type, serialize_aggregate.
#
module Hecks
  module MCP
    class DomainServer
      module CommandTools
        private

        def register_command_tools
          @domain.aggregates.each do |agg|
            agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
            agg.commands.each do |cmd|
              register_command(agg, agg_class, cmd)
            end
          end
        end

        def register_command(agg, agg_class, cmd)
          method_name = derive_method_name(cmd.name, agg.name)
          props = cmd.attributes.each_with_object({}) do |attr, h|
            h[attr.name.to_s] = { type: json_type(attr), description: "#{attr.name} (#{attr.ruby_type})" }
          end
          required = cmd.attributes.map { |a| a.name.to_s }
          klass = agg_class

          @server.define_tool(
            name: cmd.name,
            description: "#{cmd.name} — #{agg.name} action",
            input_schema: { type: "object", properties: props, required: required }
          ) do |args|
            attrs = args.transform_keys(&:to_sym)
            result = klass.send(method_name, **attrs)
            serialize_aggregate(result)
          end
        end
      end
    end
  end
end
