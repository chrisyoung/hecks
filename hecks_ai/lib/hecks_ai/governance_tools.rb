module Hecks
  module MCP
    # Hecks::MCP::GovernanceTools
    #
    # MCP tools for AI governance. Exposes the domain's world goals and
    # governance constraints so AI agents can self-orient before acting.
    #
    # Registered tools:
    #   - +explain_governance+ -- lists active world goals and their constraints
    #   - +check_governance+   -- checks if a specific command passes governance
    #
    #   # MCP tool call
    #   explain_governance({})
    #   # => { goals: [:transparency, :consent], constraints: [...] }
    #
    module GovernanceTools
      GOAL_DESCRIPTIONS = {
        transparency: "Every command must emit at least one domain event. " \
                      "Silent mutations are not allowed.",
        consent: "Commands on user-like aggregates (User, Account, Patient, etc.) " \
                 "must declare an actor. No anonymous actions on personal data.",
        privacy: "PII attributes must be marked visible: false. Commands on " \
                 "aggregates with PII must declare an actor for audit trails.",
        security: "Command-level actors must be declared at the domain level. " \
                  "No dangling or misspelled role references."
      }.freeze

      # Registers governance tools on the given MCP server.
      #
      # @param server [MCP::Server] the MCP server instance
      # @param ctx [Hecks::McpServer] shared context with session access
      # @return [void]
      def self.register(server, ctx)
        register_explain(server, ctx)
        register_check(server, ctx)
      end

      # @api private
      def self.register_explain(server, ctx)
        server.define_tool(
          name: "explain_governance",
          description: "List active world goals and their constraints for the current domain",
          input_schema: { type: "object", properties: {} }
        ) do |_|
          ctx.ensure_session!
          domain = ctx.workshop.to_domain
          goals = domain.world_goals

          if goals.empty?
            JSON.generate({ goals: [], message: "No world goals declared. All actions are allowed." })
          else
            constraints = goals.map do |g|
              { goal: g, description: GOAL_DESCRIPTIONS.fetch(g, "Custom goal: #{g}") }
            end
            JSON.generate({ goals: goals, constraints: constraints })
          end
        end
      end

      # @api private
      def self.register_check(server, ctx)
        server.define_tool(
          name: "check_governance",
          description: "Check if a command passes governance rules before executing it",
          input_schema: {
            type: "object",
            properties: {
              command: { type: "string", description: "Command name to check (e.g. CreatePatient)" }
            },
            required: ["command"]
          }
        ) do |args|
          ctx.ensure_session!
          domain = ctx.workshop.to_domain
          guard = Hecks::GovernanceGuard.new(domain)
          result = guard.check(args["command"])
          JSON.generate(result)
        end
      end
    end
  end
end
