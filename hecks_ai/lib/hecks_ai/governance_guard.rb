module Hecks
  module MCP
    # Hecks::MCP::GovernanceGuard
    #
    # Middleware that checks proposed command executions against the active
    # domain's world_goals before allowing them to proceed. Runs the domain
    # validator and extracts world-goals-specific violations. If violations
    # are found, returns a structured refusal instead of executing.
    #
    # Used by PlayTools#execute_command to gate AI actions through governance.
    #
    #   guard = GovernanceGuard.new(ctx)
    #   result = guard.check("CreatePatient", ssn: "123")
    #   result[:allowed]     # => true or false
    #   result[:violations]  # => ["Privacy: Patient#CreatePatient ..."]
    #
    class GovernanceGuard
      # @param ctx [Hecks::McpServer] shared MCP context with workshop access
      def initialize(ctx)
        @ctx = ctx
      end

      # Check whether a command is allowed under the active world goals.
      # Returns a hash with :allowed and :violations keys.
      #
      # @param command_name [String] the command to check (e.g. "CreatePatient")
      # @return [Hash] { allowed: Boolean, violations: Array<String>, goals: Array<Symbol> }
      def check(command_name)
        domain = @ctx.workshop.to_domain
        goals = domain.world_goals

        return { allowed: true, violations: [], goals: [] } if goals.empty?

        validator = Hecks::Validator.new(domain)
        validator.valid?

        relevant = filter_violations(validator.world_goals_errors, command_name, domain)

        {
          allowed: relevant.empty?,
          violations: relevant,
          goals: goals
        }
      end

      private

      # Filter world goals errors to those relevant to the given command.
      # Matches on the command name or the aggregate that owns it.
      #
      # @param errors [Array<String>] all world goals errors
      # @param command_name [String] the command being executed
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain
      # @return [Array<String>] filtered violations
      def filter_violations(errors, command_name, domain)
        agg = domain.aggregate_for_command(command_name)
        return errors if agg.nil?

        errors.select do |err|
          err.include?(command_name) || err.include?(agg.name)
        end
      end
    end
  end
end
