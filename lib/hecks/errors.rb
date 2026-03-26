# Hecks::Errors
#
# Custom error hierarchy for the Hecks framework. Provides specific
# exception types for guard rejections, domain loading, migrations,
# validation, and configuration failures.
#
#   raise Hecks::GuardRejected, "Must be admin"
#   raise Hecks::MigrationError, "Column already exists"
#
module Hecks
  class Error < StandardError; end
  class ValidationError < Error; end
  class GuardRejected < Error; end
  class PreconditionError < Error; end
  class PostconditionError < Error; end
  class DomainLoadError < Error; end
  class MigrationError < Error; end
  class ConfigurationError < Error; end
  class PortAccessDenied < Error; end
  class Unauthenticated < Error; end
  class Unauthorized < Error; end
  class RateLimitExceeded < Error; end
end
