# Hecks::MCP::DomainServer::CommandTools
#
# Mixin that registers MCP tools for domain commands. Each command on each
# aggregate becomes a callable MCP tool with a typed JSON Schema input.
#
# When a tool is invoked, it translates the JSON arguments into keyword
# arguments and calls the corresponding method on the generated aggregate
# class. The result is serialized back to a human-readable string.
#
# Mixed into DomainServer -- expects the following instance state:
#   - +@server+ [MCP::Server] -- the MCP server to register tools on
#   - +@domain+ [Hecks::DomainModel::Structure::Domain] -- the domain model
#   - +@mod+ [Module] -- the generated domain module (e.g. PizzasDomain)
#
# Also expects these helper methods from DomainServer:
#   - +derive_method_name(cmd_name, agg_name)+ -- maps command name to method symbol
#   - +json_type(attr)+ -- converts a domain attribute to a JSON Schema type
#   - +serialize_aggregate(obj)+ -- formats a domain object as a readable string
#
module Hecks
  module MCP
    class DomainServer
      module CommandTools
        private

        # Iterates all aggregates in the domain and registers each of their
        # commands as an MCP tool.
        #
        # @return [void]
        def register_command_tools
          @domain.aggregates.each do |agg|
            agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
            agg.commands.each do |cmd|
              register_command(agg, agg_class, cmd)
            end
          end
        end

        # Registers a single command as an MCP tool. Builds a JSON Schema from
        # the command's attributes and wires the tool to call the corresponding
        # class method on the aggregate.
        #
        # @param agg [Hecks::DomainModel::Structure::Aggregate] the aggregate owning the command
        # @param agg_class [Class] the generated Ruby class for the aggregate
        # @param cmd [Hecks::DomainModel::Behavior::Command] the command to register
        # @return [void]
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
