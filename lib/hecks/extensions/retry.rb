# HecksRetry
#
# Command bus middleware that auto-retries failed commands with exponential
# backoff. Only retries on transient errors (network, timeout). Domain errors
# (Hecks::Error subclasses like ValidationError, GuardRejected) are never
# retried and propagate immediately.
#
# Configuration via environment variables:
#   HECKS_RETRY_MAX   — maximum retry attempts (default: 3)
#   HECKS_RETRY_DELAY — base delay in seconds (default: 0.1)
#
# Future gem: hecks_retry
#
#   require "hecks_retry"
#   # Automatically registered — transient failures will be retried
#   # up to HECKS_RETRY_MAX times with exponential backoff.
#
require "hecks"

Hecks.describe_extension(:retry,
  description: "Automatic command retry with backoff",
  config: { max_attempts: { default: 3, desc: "Max retry attempts" } },
  wires_to: :command_bus)

Hecks.register_extension(:retry) do |domain_mod, domain, runtime|
  max_retries = ENV.fetch("HECKS_RETRY_MAX", "3").to_i
  base_delay = ENV.fetch("HECKS_RETRY_DELAY", "0.1").to_f

  runtime.use :retry do |command, next_handler|
    attempts = 0
    begin
      attempts += 1
      next_handler.call
    rescue Hecks::Error
      raise  # domain errors are not retried
    rescue StandardError => e
      if attempts < max_retries
        sleep(base_delay * (2 ** (attempts - 1)))
        retry
      end
      raise
    end
  end
end
