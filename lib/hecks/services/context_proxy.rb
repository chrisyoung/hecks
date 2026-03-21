# Hecks::Services::ContextProxy
#
# Proxy for context-qualified repository access in multi-context domains.
# Returned by Application#[] when the domain has explicit bounded contexts.
#
#   app["Ordering"]["Order"]  # => repository for Order in Ordering context
#
module Hecks
  module Services
    class ContextProxy
      def initialize(context, repositories)
        @context = context
        @repositories = repositories
      end

      def [](aggregate_name)
        @repositories["#{@context.name}/#{aggregate_name}"]
      end
    end
  end
end
