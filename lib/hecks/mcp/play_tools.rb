# Hecks::MCP::PlayTools
#
# MCP tools for play mode — execute actions, see events, view history.
#
module Hecks
  module MCP
    module PlayTools
      def self.register(server, ctx)
        server.define_tool(
          name: "enter_play_mode",
          description: "Switch to play mode — try out actions",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.session.play!
          "Play mode active. Use execute_command to try actions."
        end

        server.define_tool(
          name: "exit_play_mode",
          description: "Switch back to build mode",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.session.build!
          "Back to build mode."
        end

        server.define_tool(
          name: "execute_command",
          description: "Execute an action (e.g. CreatePizza)",
          input_schema: {
            type: "object",
            properties: {
              command: { type: "string", description: "Action name" },
              attrs: { type: "object", description: "Attributes" }
            },
            required: ["command"]
          }
        ) do |args|
          ctx.ensure_session!
          attrs = (args["attrs"] || {}).transform_keys(&:to_sym)
          ctx.capture_output { ctx.session.execute(args["command"], **attrs) }
        end

        server.define_tool(
          name: "list_commands",
          description: "List available actions in play mode",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.session.commands.join("\n")
        end

        server.define_tool(
          name: "show_history",
          description: "Show the event timeline",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.capture_output { ctx.session.history }
        end

        server.define_tool(
          name: "reset_playground",
          description: "Clear events and start over",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          ctx.session.reset!
          "Playground reset."
        end
      end
    end
  end
end
