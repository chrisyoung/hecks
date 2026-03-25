# HecksAuth
#
# Authentication and authorization connection for Hecks domains. Reads
# actor metadata from the DSL and registers command bus middleware that
# enforces access control. Commands without actors are always allowed.
#
# Future gem: hecks_auth
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_auth"
#
#   # Set the current actor (any object responding to #role)
#   Hecks.actor = OpenStruct.new(role: "Admin")
#   Cat.adopt(name: "Whiskers")  # checks actor role against DSL
#
Hecks.register_connection(:auth) do |domain_mod, domain, runtime|
  # Build a lookup of command class name → required actor roles
  actor_map = {}
  domain.aggregates.each do |agg|
    agg.commands.each do |cmd|
      next if cmd.actors.empty?
      fqn = "#{domain_mod.name}::#{agg.name}::Commands::#{cmd.name}"
      actor_map[fqn] = cmd.actors.map(&:name)
    end
  end

  next if actor_map.empty?

  runtime.use :auth do |command, next_handler|
    fqn = command.class.name
    required_roles = actor_map[fqn]

    if required_roles
      actor = Hecks.actor
      raise Hecks::Unauthenticated, "No actor set. Call Hecks.actor = user before running #{command.class.name.split('::').last}" unless actor
      role = actor.respond_to?(:role) ? actor.role.to_s : actor.to_s
      unless required_roles.include?(role)
        raise Hecks::Unauthorized, "Actor '#{role}' is not authorized for #{command.class.name.split('::').last}. Required: #{required_roles.join(', ')}"
      end
    end

    next_handler.call
  end
end
