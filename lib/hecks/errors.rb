# = Hecks::Errors
#
# Custom error hierarchy for the Hecks framework. All Hecks exceptions
# inherit from {Hecks::Error}, which itself inherits from +StandardError+.
#
# This module defines specific exception types for different failure modes
# across the framework:
#
# - *Validation* -- Domain model validation failures (e.g., missing attributes,
#   invalid types)
# - *Guards* -- Command guard rejections (precondition checks that block execution)
# - *Conditions* -- Pre/post-condition contract violations
# - *Domain loading* -- Failures when parsing or compiling domain definitions
# - *Migrations* -- Schema migration errors (e.g., column conflicts)
# - *Configuration* -- Invalid or missing configuration settings
# - *Access control* -- Port access, authentication, authorization, and rate limiting
#
# == Usage
#
#   raise Hecks::GuardRejected, "Must be admin"
#   raise Hecks::MigrationError, "Column already exists"
#   raise Hecks::ValidationError, "Name cannot be blank"
#
#   begin
#     app["Pizza"].create(name: "")
#   rescue Hecks::ValidationError => e
#     puts e.message
#   end
#
module Hecks
  # Base error class for all Hecks framework exceptions. Rescue this to
  # catch any Hecks-specific error.
  class Error < StandardError; end

  # Raised when a domain model fails validation (e.g., blank required
  # attribute, invalid enum value, type mismatch).
  class ValidationError < Error; end

  # Raised when a command guard rejects execution. Guards are precondition
  # checks defined on commands that prevent invalid state transitions.
  class GuardRejected < Error; end

  # Raised when a precondition (defined via +pre+ in a lifecycle) is not met
  # before a command executes.
  class PreconditionError < Error; end

  # Raised when a postcondition (defined via +post+ in a lifecycle) is not met
  # after a command executes, indicating the command produced invalid state.
  class PostconditionError < Error; end

  # Raised when a domain definition cannot be loaded or parsed (e.g.,
  # missing domain.rb file, syntax error in DSL, unresolvable references).
  class DomainLoadError < Error; end

  # Raised when a schema migration fails (e.g., attempting to add a column
  # that already exists, incompatible type change).
  class MigrationError < Error; end

  # Raised when configuration is invalid or incomplete (e.g., missing
  # required adapter setting, unknown extension name).
  class ConfigurationError < Error; end

  # Raised when code attempts to access a port (command, query, repository)
  # that is not exposed or not permitted for the current context.
  class PortAccessDenied < Error; end

  # Raised when an operation requires authentication but no actor is set
  # (i.e., +Hecks.actor+ is nil).
  class Unauthenticated < Error; end

  # Raised when the current actor does not have permission to perform the
  # requested operation (actor is set but lacks required role/privilege).
  class Unauthorized < Error; end

  # Raised when a rate limit is exceeded for a command or query operation.
  class RateLimitExceeded < Error; end
end
