# HecksRateLimit
#
# Rate limiting connection for Hecks command bus. Uses a sliding window
# counter per actor to limit how many commands an actor can dispatch in
# a configurable time period. Controlled via ENV vars:
#
#   HECKS_RATE_LIMIT  — max commands per window (default: 60)
#   HECKS_RATE_PERIOD — window size in seconds (default: 60)
#
# Usage:
#
#   require "hecks_rate_limit"
#   Hecks.actor = current_user
#   app.run("CreatePizza", name: "Margherita")  # rate-limited per actor
#
Hecks.register_extension(:rate_limit) do |_domain_mod, _domain, runtime|
  window = {}
  limit = ENV.fetch("HECKS_RATE_LIMIT", "60").to_i
  period = ENV.fetch("HECKS_RATE_PERIOD", "60").to_i

  runtime.use :rate_limit do |command, next_handler|
    actor = Hecks.actor
    if actor
      key = "#{actor.respond_to?(:id) ? actor.id : actor}:#{command.class.name}"
      now = Time.now.to_f
      window[key] ||= []
      window[key].reject! { |t| t < now - period }
      if window[key].size >= limit
        raise Hecks::RateLimitExceeded, "Rate limit exceeded (#{limit}/#{period}s)"
      end
      window[key] << now
    end
    next_handler.call
  end
end
