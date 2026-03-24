# Hecks::MCP::AggregateTools
#
# MCP tools for building domain structure: add/remove aggregates, commands,
# value objects, validations, and policies. Each tool delegates to the
# Session's AggregateHandle API.
#
module Hecks
  module MCP
    module AggregateTools
      def self.register(server, ctx)
        server.define_tool(
          name: "add_aggregate",
          description: "Add a new thing to the domain (e.g. Pizza, Order)",
          input_schema: {
            type: "object",
            properties: {
              name: { type: "string", description: "Name (PascalCase)" },
              attributes: { type: "array", items: { type: "object", properties: { name: { type: "string" }, type: { type: "string" } } } }
            },
            required: ["name"]
          }
        ) do |args|
          ctx.ensure_session!
          handle = ctx.session.aggregate(args["name"])
          (args["attributes"] || []).each do |attr|
            handle.add_attribute(attr["name"].to_sym, ctx.resolve_type(attr["type"]))
          end
          "Added #{args["name"]} with #{(args["attributes"] || []).size} attributes"
        end

        server.define_tool(
          name: "add_command",
          description: "Add an action (e.g. CreatePizza, PlaceOrder)",
          input_schema: {
            type: "object",
            properties: {
              aggregate: { type: "string" },
              name: { type: "string", description: "Verb + thing (e.g. CreatePizza)" },
              attributes: { type: "array", items: { type: "object", properties: { name: { type: "string" }, type: { type: "string" } } } }
            },
            required: ["aggregate", "name"]
          }
        ) do |args|
          ctx.ensure_session!
          handle = ctx.session.aggregate(args["aggregate"])
          attrs = args["attributes"] || []
          resolved = attrs.map { |a| [a["name"].to_sym, ctx.resolve_type(a["type"])] }
          handle.add_command(args["name"]) do
            resolved.each { |name, type| attribute name, type }
          end
          "Added action #{args["name"]} to #{args["aggregate"]}"
        end

        server.define_tool(
          name: "add_value_object",
          description: "Add an embedded detail (e.g. Topping on Pizza)",
          input_schema: {
            type: "object",
            properties: {
              aggregate: { type: "string" },
              name: { type: "string" },
              attributes: { type: "array", items: { type: "object", properties: { name: { type: "string" }, type: { type: "string" } } } }
            },
            required: ["aggregate", "name"]
          }
        ) do |args|
          ctx.ensure_session!
          handle = ctx.session.aggregate(args["aggregate"])
          resolved = (args["attributes"] || []).map { |a| [a["name"].to_sym, ctx.resolve_type(a["type"])] }
          handle.add_value_object(args["name"]) do
            resolved.each { |name, type| attribute name, type }
          end
          "Added #{args["name"]} to #{args["aggregate"]}"
        end

        server.define_tool(
          name: "add_entity",
          description: "Add a sub-entity with identity (e.g. LedgerEntry on Account)",
          input_schema: {
            type: "object",
            properties: {
              aggregate: { type: "string" },
              name: { type: "string" },
              attributes: { type: "array", items: { type: "object", properties: { name: { type: "string" }, type: { type: "string" } } } }
            },
            required: ["aggregate", "name"]
          }
        ) do |args|
          ctx.ensure_session!
          handle = ctx.session.aggregate(args["aggregate"])
          resolved = (args["attributes"] || []).map { |a| [a["name"].to_sym, ctx.resolve_type(a["type"])] }
          handle.add_entity(args["name"]) do
            resolved.each { |name, type| attribute name, type }
          end
          "Added entity #{args["name"]} to #{args["aggregate"]}"
        end

        server.define_tool(
          name: "add_validation",
          description: "Add a requirement (e.g. name must be present)",
          input_schema: {
            type: "object",
            properties: { aggregate: { type: "string" }, field: { type: "string" }, presence: { type: "boolean" } },
            required: ["aggregate", "field"]
          }
        ) do |args|
          ctx.ensure_session!
          handle = ctx.session.aggregate(args["aggregate"])
          rules = {}
          rules[:presence] = true if args["presence"]
          handle.add_validation(args["field"].to_sym, rules)
          "Added validation on #{args["field"]} for #{args["aggregate"]}"
        end

        server.define_tool(
          name: "add_policy",
          description: "Add a reaction — when event happens, trigger action",
          input_schema: {
            type: "object",
            properties: {
              aggregate: { type: "string" }, name: { type: "string" },
              on_event: { type: "string" }, trigger: { type: "string" }
            },
            required: ["aggregate", "name", "on_event", "trigger"]
          }
        ) do |args|
          ctx.ensure_session!
          handle = ctx.session.aggregate(args["aggregate"])
          evt, trig = args["on_event"], args["trigger"]
          handle.add_policy(args["name"]) { on evt; trigger trig }
          "When #{evt} → #{trig}"
        end

        server.define_tool(
          name: "remove_aggregate",
          description: "Remove a thing from the domain",
          input_schema: { type: "object", properties: { name: { type: "string" } }, required: ["name"] }
        ) do |args|
          ctx.ensure_session!
          ctx.session.remove(args["name"])
          "Removed #{args["name"]}"
        end
      end
    end
  end
end
