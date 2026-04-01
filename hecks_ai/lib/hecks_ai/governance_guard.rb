module Hecks
  # Hecks::GovernanceGuard
  #
  # General-purpose governance layer that checks proposed command executions
  # against a domain's world_goals before allowing them to proceed. Runs the
  # domain validator and extracts world-goals-specific violations. If violations
  # are found, returns a structured refusal instead of executing.
  #
  # Entry-point agnostic: works from CLI, HTTP, REPL, or MCP. Accepts a domain
  # object directly -- callers are responsible for obtaining the domain from
  # whatever context they have (workshop, compiled app, etc.).
  #
  #   domain = workshop.to_domain
  #   guard  = Hecks::GovernanceGuard.new(domain)
  #   result = guard.check("CreatePatient")
  #   result[:allowed]     # => true or false
  #   result[:violations]  # => ["Privacy: Patient#CreatePatient ..."]
  #
  class GovernanceGuard
    # @param domain [Hecks::DomainModel::Structure::Domain] the domain to check against
    def initialize(domain)
      @domain = domain
    end

    # Check whether a command is allowed under the active world goals.
    # Returns a hash with :allowed and :violations keys.
    #
    # @param command_name [String] the command to check (e.g. "CreatePatient")
    # @return [Hash] { allowed: Boolean, violations: Array<String>, goals: Array<Symbol> }
    def check(command_name)
      goals = @domain.world_goals

      return { allowed: true, violations: [], goals: [] } if goals.empty?

      validator = Hecks::Validator.new(@domain)
      validator.valid?

      relevant = filter_violations(validator.world_goals_errors, command_name, @domain)

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
